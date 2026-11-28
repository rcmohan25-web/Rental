import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart' show AppException;
import 'package:rental_data/rental_data.dart';

void main() {
  final rows = <Map<String, dynamic>>[
    {'key': 'commission_rate', 'value': 0.1},
    {'key': 'deposit_rate', 'value': 0.2},
    {'key': 'late_fee_multiplier', 'value': 1.5},
  ];

  group('AppSettings.minDepositAmount', () {
    test('is read when present and left null when not set', () {
      final unset = AppSettings.fromRows(rows);
      expect(unset.minDepositAmount, isNull);
      expect(unset.toKeyValues().containsKey('min_deposit_amount'), isFalse);

      final set = AppSettings.fromRows([
        ...rows,
        {'key': 'min_deposit_amount', 'value': 1000},
      ]);
      expect(set.minDepositAmount, 1000);
      expect(set.toKeyValues()['min_deposit_amount'], 1000);
      expect(AppSettings.fromKeyValues(set.toKeyValues()), set);
    });

    test('accepts the number the database returns (1000.0) but not 10.5', () {
      expect(
        AppSettings.fromRows([
          ...rows,
          {'key': 'min_deposit_amount', 'value': 1000.0},
        ]).minDepositAmount,
        1000,
      );
      expect(
        () => AppSettings.fromRows([
          ...rows,
          {'key': 'min_deposit_amount', 'value': 10.5},
        ]),
        throwsFormatException,
      );
    });

    test('a negative minimum is an error', () {
      expect(
        () => AppSettings.fromRows([
          ...rows,
          {'key': 'min_deposit_amount', 'value': -1},
        ]),
        throwsFormatException,
      );
    });
  });

  group('Booking.minDepositAmount', () {
    final seed = FakeData.seedBookings(DateTime(2026, 11, 1)).first;

    test('defaults to 0 and survives a JSON round trip', () {
      expect(seed.minDepositAmount, 0);
      expect(Booking.fromJson(seed.toJson()), seed);
      expect(seed.toJson()['min_deposit_amount'], 0);
    });

    test('a booking row without the column reads as 0', () {
      final json = seed.toJson()..remove('min_deposit_amount');
      expect(Booking.fromJson(json).minDepositAmount, 0);
    });

    test('a stored minimum is read back', () {
      final json = seed.toJson()..['min_deposit_amount'] = 1000;
      expect(Booking.fromJson(json).minDepositAmount, 1000);
    });
  });

  group('FakeBookingRepository applies the minimum', () {
    test('low-value item: deposit is the minimum and is snapshotted', () async {
      final settings = FakeSettingsRepository(
        settings: const AppSettings(
          commissionRateBps: 1000,
          depositRateBps: 2000,
          lateFeeMultiplierX100: 150,
          minDepositAmount: 1000,
        ),
      );
      final repo = FakeBookingRepository(
        items: FakeItemRepository(),
        settings: settings,
        clock: () => DateTime(2026, 11, 1),
      );
      // The tent: declared value 18,000, 20% is 3,600, above the minimum.
      final tent = await repo.createBookingRequest(
        itemId: 'item-6',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 10),
        idempotencyKey: 'k1',
      );
      expect(tent.deposit, 3600);
      expect(tent.minDepositAmount, 1000);

      // A bigger minimum than 20% of the backpack (12,000 -> 2,400).
      final strict = FakeBookingRepository(
        items: FakeItemRepository(),
        settings: FakeSettingsRepository(
          settings: const AppSettings(
            commissionRateBps: 1000,
            depositRateBps: 2000,
            lateFeeMultiplierX100: 150,
            minDepositAmount: 5000,
          ),
        ),
        clock: () => DateTime(2026, 11, 1),
      );
      final pack = await strict.createBookingRequest(
        itemId: 'item-7',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 10),
        idempotencyKey: 'k2',
      );
      expect(pack.deposit, 5000);
      expect(pack.borrowerPays, 400 + 5000);
    });

    test('settings without a minimum behave as before', () async {
      final repo = FakeBookingRepository(
        items: FakeItemRepository(),
        settings: FakeSettingsRepository(),
        clock: () => DateTime(2026, 11, 1),
      );
      final b = await repo.createBookingRequest(
        itemId: 'item-1',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 12),
        idempotencyKey: 'k3',
      );
      expect(b.deposit, 32000);
      expect(b.minDepositAmount, 0);
    });
  });

  test('AppException import keeps the error type visible to the tests', () {
    expect(const AppException('x', code: 'X').code, 'X');
  });
}
