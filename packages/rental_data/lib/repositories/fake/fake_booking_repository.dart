import 'dart:async';

import 'package:rental_core/rental_core.dart' show AppException, Money;

import '../../models/models.dart';
import '../booking_repository.dart';
import '../item_repository.dart';
import '../settings_repository.dart';
import 'fake_data.dart';

/// In-memory bookings that apply the same checks as `create_booking_request`
/// (docs/api-contract.md section 6.1), so screens can be built and tested
/// before the database exists.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    required this.items,
    required this.settings,
    this.currentUserId = FakeData.borrowerId,
    this.kycStatus = KycStatus.verified,
    List<Booking>? seedBookings,
    DateTime Function()? clock,
    this.latency = Duration.zero,
  })  : _clock = clock ?? DateTime.now,
        _bookings = [],
        _controller = StreamController<List<Booking>>.broadcast() {
    _bookings.addAll(seedBookings ?? FakeData.seedBookings(_clock()));
  }

  final ItemRepository items;
  final SettingsRepository settings;

  /// The signed-in Borrower.
  final String currentUserId;

  /// Set to [KycStatus.none] to see KYC_REQUIRED.
  final KycStatus kycStatus;
  final Duration latency;
  final DateTime Function() _clock;
  final List<Booking> _bookings;
  final StreamController<List<Booking>> _controller;
  int _counter = 0;

  @override
  Future<Booking> createBookingRequest({
    required String itemId,
    required DateTime startDate,
    required DateTime endDate,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(latency);

    if (kycStatus == KycStatus.none) _fail('KYC_REQUIRED');

    // Same key from the same Borrower returns the original booking.
    for (final b in _bookings) {
      if (b.borrowerId == currentUserId && b.idempotencyKey == idempotencyKey) {
        return b;
      }
    }

    final Item item;
    try {
      item = await items.getItem(itemId);
    } on AppException {
      _fail('ITEM_UNAVAILABLE');
    }
    if (item.lenderId == currentUserId) _fail('OWN_ITEM');

    final today = _dateOnly(_clock());
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (start.isBefore(today) || end.isBefore(start)) _fail('INVALID_DATES');

    final blocked = await blockedDates(itemId);
    if (blocked.any((r) => r.overlaps(start, end))) _fail('DATES_TAKEN');

    final duplicate = _bookings.any(
      (b) =>
          b.itemId == itemId &&
          b.borrowerId == currentUserId &&
          b.status == BookingStatus.requested &&
          DateRange(b.startDate, b.endDate).overlaps(start, end),
    );
    if (duplicate) _fail('DUPLICATE_REQUEST');

    final s = await settings.getSettings();
    final amounts = Money.breakdown(
      start: start,
      end: end,
      dailyPrice: item.dailyPrice,
      declaredValue: item.declaredValue,
      depositRateBps: s.depositRateBps,
      commissionRateBps: s.commissionRateBps,
    );
    final now = _clock().toUtc();
    _counter++;
    final booking = Booking(
      id: 'fake-booking-$_counter',
      itemId: item.id,
      lenderId: item.lenderId,
      borrowerId: currentUserId,
      startDate: start,
      endDate: end,
      status: BookingStatus.requested,
      days: amounts.days,
      dailyPrice: item.dailyPrice,
      declaredValue: item.declaredValue,
      rentalFee: amounts.rentalFee,
      deposit: amounts.deposit,
      commissionRateBps: s.commissionRateBps,
      depositRateBps: s.depositRateBps,
      commissionAmount: amounts.commission,
      renterEarning: amounts.renterEarning,
      lateFeeMultiplierX100: s.lateFeeMultiplierX100,
      returnGraceHours: s.returnGraceHours,
      termsVersionIds: FakeData.termsVersionIds,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      updatedAt: now,
    );
    _bookings.add(booking);
    _notify();
    return booking;
  }

  @override
  Future<Booking> cancelBooking(String bookingId, {String? reason}) async {
    await Future<void>.delayed(latency);
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1 || _bookings[index].borrowerId != currentUserId) {
      _fail('NOT_ALLOWED');
    }
    final current = _bookings[index];
    if (!current.status.borrowerCanCancel) _fail('INVALID_STATE');
    final updated = current.copyWith(
      status: BookingStatus.cancelled,
      updatedAt: _clock().toUtc(),
    );
    _bookings[index] = updated;
    _notify();
    return updated;
  }

  @override
  Future<List<Booking>> listMyBookings() async {
    await Future<void>.delayed(latency);
    return _mine();
  }

  @override
  Future<Booking> getBooking(String bookingId) async {
    await Future<void>.delayed(latency);
    for (final b in _bookings) {
      final isParty =
          b.borrowerId == currentUserId || b.lenderId == currentUserId;
      if (b.id == bookingId && isParty) return b;
    }
    _fail('NOT_ALLOWED');
  }

  @override
  Stream<List<Booking>> watchMyBookings() async* {
    yield _mine();
    yield* _controller.stream;
  }

  @override
  Future<List<DateRange>> blockedDates(String itemId) async {
    await Future<void>.delayed(latency);
    return [
      for (final b in _bookings)
        if (b.itemId == itemId && b.status.blocksDates)
          DateRange(b.startDate, b.endDate),
    ];
  }

  /// Test helper: stop the stream controller.
  Future<void> dispose() => _controller.close();

  List<Booking> _mine() {
    final mine = _bookings.where((b) => b.borrowerId == currentUserId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(_mine());
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The message is the code; screens map the code to friendly text.
  Never _fail(String code) => throw AppException(code, code: code);
}
