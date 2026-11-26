import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart';

/// Reads shared/fixtures/money_cases.json. `flutter test` runs from the
/// package folder, so the repo root is two folders up.
Map<String, dynamic> _loadFixtures() {
  final file = File('../../shared/fixtures/money_cases.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final fixtures = _loadFixtures();

  group('Money.breakdown (fixtures)', () {
    for (final c in fixtures['breakdown'] as List<dynamic>) {
      final testCase = c as Map<String, dynamic>;
      test(testCase['name'] as String, () {
        final i = testCase['input'] as Map<String, dynamic>;
        final e = testCase['expected'] as Map<String, dynamic>;
        final r = Money.breakdown(
          start: DateTime.parse(i['start'] as String),
          end: DateTime.parse(i['end'] as String),
          dailyPrice: i['dailyPrice'] as int,
          declaredValue: i['declaredValue'] as int,
          depositRateBps: i['depositRateBps'] as int,
          commissionRateBps: i['commissionRateBps'] as int,
        );
        expect(r.days, e['days']);
        expect(r.rentalFee, e['rentalFee']);
        expect(r.deposit, e['deposit']);
        expect(r.commission, e['commission']);
        expect(r.renterEarning, e['renterEarning']);
        expect(r.borrowerPays, e['borrowerPays']);
      });
    }
  });

  group('Money.lateDays and Money.lateFee (fixtures)', () {
    for (final c in fixtures['lateFee'] as List<dynamic>) {
      final testCase = c as Map<String, dynamic>;
      test(testCase['name'] as String, () {
        final days = Money.lateDays(
          DateTime.parse(testCase['endDate'] as String),
          DateTime.parse(testCase['returnedAt'] as String),
          testCase['graceHours'] as int,
        );
        expect(days, testCase['expectedLateDays']);
        final fee = Money.lateFee(
          dailyPrice: testCase['dailyPrice'] as int,
          lateDays: days,
          multiplierX100: testCase['multiplierX100'] as int,
          deposit: testCase['deposit'] as int,
        );
        expect(fee, testCase['expectedFee']);
      });
    }
  });

  group('database fractions (fixtures)', () {
    for (final c in fixtures['breakdown'] as List<dynamic>) {
      final testCase = c as Map<String, dynamic>;
      test('rates convert: ${testCase['name']}', () {
        final i = testCase['input'] as Map<String, dynamic>;
        expect(Money.bpsFromRate(i['depositRate'] as num), i['depositRateBps']);
        expect(
          Money.bpsFromRate(i['commissionRate'] as num),
          i['commissionRateBps'],
        );
        expect(Money.rateFromBps(i['depositRateBps'] as int), i['depositRate']);
      });
    }

    test('late fee multiplier 1.5 is 150 and back', () {
      expect(Money.multiplierX100FromFactor(1.5), 150);
      expect(Money.factorFromMultiplierX100(150), 1.5);
    });

    test('negative rate throws', () {
      expect(() => Money.bpsFromRate(-0.1), throwsArgumentError);
    });
  });

  group('plan worked example (readable version of case 1)', () {
    test('3 days x NPR 3,500 with NPR 160,000 declared value', () {
      final r = Money.breakdown(
        start: DateTime(2026, 11, 6),
        end: DateTime(2026, 11, 8),
        dailyPrice: 3500,
        declaredValue: 160000,
        depositRateBps: 2000,
        commissionRateBps: 1000,
      );
      expect(r.rentalFee, 10500);
      expect(r.deposit, 32000);
      expect(r.commission, 1050);
      expect(r.renterEarning, 9450);
      expect(r.borrowerPays, 42500);
    });
  });

  group('approved v0.3 boundary examples', () {
    test('declared value 5 at 20% gives a deposit of 1', () {
      expect(Money.deposit(5, 2000), 1);
    });

    test('rental fee 5 at 10% gives a commission of 1 (0.5 rounds half up)',
        () {
      expect(Money.applyRate(5, 1000), 1);
    });

    test('deposit rounds at .5: 1.4 gives 1 and 1.6 gives 2', () {
      expect(Money.deposit(7, 2000), 1);
      expect(Money.deposit(8, 2000), 2);
    });

    test('a 20% deposit can never land exactly on .5 for whole NPR values', () {
      for (var value = 0; value < 1000; value++) {
        final tenths = value * 2000 % 10000;
        expect(tenths == 5000, isFalse);
      }
    });
  });

  group('Money.days', () {
    test('same day is 1 day', () {
      expect(Money.days(DateTime(2026, 11, 6), DateTime(2026, 11, 6)), 1);
    });

    test('time of day is ignored', () {
      final start = DateTime(2026, 11, 6, 23, 59);
      final end = DateTime(2026, 11, 7, 0, 1);
      expect(Money.days(start, end), 2);
    });

    test('leap day is counted', () {
      expect(Money.days(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 3);
    });
  });

  group('invalid input', () {
    test('end before start throws', () {
      expect(
        () => Money.days(DateTime(2026, 11, 8), DateTime(2026, 11, 6)),
        throwsArgumentError,
      );
    });

    test('zero daily price throws', () {
      expect(() => Money.rentalFee(3, 0), throwsArgumentError);
    });

    test('zero days throws', () {
      expect(() => Money.rentalFee(0, 3500), throwsArgumentError);
    });

    test('negative amount throws', () {
      expect(() => Money.applyRate(-1, 1000), throwsArgumentError);
    });

    test('negative grace hours throws', () {
      expect(
        () => Money.lateDays(DateTime(2026, 11, 8), DateTime(2026, 11, 9), -1),
        throwsArgumentError,
      );
    });

    test('no late days means no late fee', () {
      expect(
        Money.lateFee(
          dailyPrice: 3500,
          lateDays: 0,
          multiplierX100: 150,
          deposit: 32000,
        ),
        0,
      );
    });
  });
}
