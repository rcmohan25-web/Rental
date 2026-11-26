import '../models/models.dart';

/// Borrower-side booking calls. Each method maps to one RPC in
/// docs/api-contract.md. Failures throw AppException whose `code` is one of
/// the contract's error codes (for example DATES_TAKEN).
abstract class BookingRepository {
  /// `create_booking_request`. The server calculates every amount.
  /// Repeating the call with the same [idempotencyKey] returns the same booking.
  Future<Booking> createBookingRequest({
    required String itemId,
    required DateTime startDate,
    required DateTime endDate,
    required String idempotencyKey,
  });

  /// `cancel_booking` (proposed in the contract).
  Future<Booking> cancelBooking(String bookingId, {String? reason});

  /// The signed-in Borrower's bookings, newest first.
  Future<List<Booking>> listMyBookings();

  /// One booking the caller is a party to.
  Future<Booking> getBooking(String bookingId);

  /// Same list as [listMyBookings], pushed again whenever it changes
  /// (Supabase Realtime in the real repository).
  Stream<List<Booking>> watchMyBookings();

  /// `get_blocked_dates`: the date ranges of bookings that hold the item
  /// (renter_accepted through handed_over).
  Future<List<DateRange>> blockedDates(String itemId);
}
