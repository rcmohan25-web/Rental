// OWNER: Smaran. The one money library for Rental.
//
// Rules (plan section 4.4, docs/business-rules.md, docs/api-contract.md v1.0 section 1):
// - All amounts are whole NPR stored in `int`. Never use `double` for money.
// - Inside Dart, rates are basis points: 1000 = 10%, 2000 = 20%. This keeps all
//   arithmetic in exact integers. The database stores fractions (commission_rate
//   0.1000, deposit_rate 0.2000, late_fee_multiplier 1.5); use bpsFromRate and
//   multiplierX100FromFactor at the edge (docs/api-contract.md section 1).
// - The late fee multiplier is x100: 150 = 1.5x.
// - Rounding is half up to whole NPR, the same as PostgreSQL `round()` on
//   non-negative numbers (approved in contract v0.3).
// - Deposit = max( round_half_up(declared value x deposit rate), minimum deposit ).
//   The minimum (`min_deposit_amount`) is a whole-NPR admin setting for
//   low-value items (supervisor decision, 23 Nov 2026). Zero means no minimum.
// - APPROVED: 20% deposit, 10% commission, 1.5x multiplier.
//   NOT approved: grace period, late-day rounding, cap and deduction rules.
//   lateDays and lateFee below are PROVISIONAL until they are.
//
// The SQL function rental_private.calculate_money gives exactly the same
// numbers. Both sides are tested with shared/fixtures/money_cases.json. Do not
// change a formula without updating the fixtures and telling Srijan.

/// The amounts for one booking, all in whole NPR.
class MoneyBreakdown {
  const MoneyBreakdown({
    required this.days,
    required this.rentalFee,
    required this.deposit,
    required this.commission,
    required this.renterEarning,
  });

  /// Inclusive number of rental days.
  final int days;

  /// days x daily price.
  final int rentalFee;

  /// Refundable deposit: max(declared value x deposit rate, minimum), rounded.
  final int deposit;

  /// Platform commission on the rental fee (taken from the Renter's earning).
  final int commission;

  /// rentalFee - commission.
  final int renterEarning;

  /// What the Borrower pays in total: rental fee plus refundable deposit.
  int get borrowerPays => rentalFee + deposit;
}

/// Money calculations. Static functions only, nothing to instantiate.
abstract final class Money {
  /// Database fraction to basis points: 0.10 gives 1000, 0.20 gives 2000.
  static int bpsFromRate(num rate) {
    if (rate < 0) throw ArgumentError('rate must not be negative');
    return (rate * 10000).round();
  }

  /// Basis points to the fraction stored in the database: 1000 gives 0.1.
  static double rateFromBps(int bps) => bps / 10000;

  /// Database late_fee_multiplier to x100: 1.5 gives 150.
  static int multiplierX100FromFactor(num factor) {
    if (factor < 0) throw ArgumentError('multiplier must not be negative');
    return (factor * 100).round();
  }

  /// x100 back to the database factor: 150 gives 1.5.
  static double factorFromMultiplierX100(int x100) => x100 / 100;

  /// Inclusive day count: 6 Nov to 8 Nov is 3 days.
  /// Only the calendar date is used, never the time of day.
  static int days(DateTime start, DateTime end) {
    final s = DateTime.utc(start.year, start.month, start.day);
    final e = DateTime.utc(end.year, end.month, end.day);
    if (e.isBefore(s)) {
      throw ArgumentError('end date must not be before start date');
    }
    return e.difference(s).inDays + 1;
  }

  /// `amount` x `rateBps`, rounded half up to whole NPR.
  /// Example: applyRate(10500, 1000) is 1050.
  static int applyRate(int amount, int rateBps) {
    if (amount < 0 || rateBps < 0) {
      throw ArgumentError('amount and rate must not be negative');
    }
    return (amount * rateBps + 5000) ~/ 10000;
  }

  /// days x daily price.
  static int rentalFee(int days, int dailyPrice) {
    if (days < 1 || dailyPrice < 1) {
      throw ArgumentError('days and daily price must be at least 1');
    }
    return days * dailyPrice;
  }

  /// Refundable deposit: a percentage of the declared value, but never below
  /// [minDepositAmount] (whole NPR, 0 means no minimum).
  /// Example: deposit(2000, 2000, minDepositAmount: 1000) is 1000.
  static int deposit(
    int declaredValue,
    int depositRateBps, {
    int minDepositAmount = 0,
  }) {
    if (minDepositAmount < 0) {
      throw ArgumentError('minimum deposit must not be negative');
    }
    final byRate = applyRate(declaredValue, depositRateBps);
    return byRate > minDepositAmount ? byRate : minDepositAmount;
  }

  /// Everything the request screen and the server snapshot need.
  static MoneyBreakdown breakdown({
    required DateTime start,
    required DateTime end,
    required int dailyPrice,
    required int declaredValue,
    required int depositRateBps,
    required int commissionRateBps,
    int minDepositAmount = 0,
  }) {
    final d = days(start, end);
    final fee = rentalFee(d, dailyPrice);
    final commission = applyRate(fee, commissionRateBps);
    return MoneyBreakdown(
      days: d,
      rentalFee: fee,
      deposit: deposit(
        declaredValue,
        depositRateBps,
        minDepositAmount: minDepositAmount,
      ),
      commission: commission,
      renterEarning: fee - commission,
    );
  }

  /// PROVISIONAL (grace period and late-day rounding are not approved yet).
  /// Whole days late. The item is on time until the end of the end date plus
  /// `graceHours`. Any part of a day after that counts as one full day.
  static int lateDays(DateTime endDate, DateTime returnedAt, int graceHours) {
    if (graceHours < 0) {
      throw ArgumentError('grace hours must not be negative');
    }
    final deadline = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    ).add(Duration(hours: graceHours));
    if (!returnedAt.isAfter(deadline)) return 0;
    final minutesLate = returnedAt.difference(deadline).inMinutes;
    // Ceiling division: 1 minute late is already 1 day.
    return (minutesLate + 1439) ~/ 1440;
  }

  /// PROVISIONAL (the cap and deposit deduction are not approved yet).
  /// Late fee = late days x daily price x multiplier, never more than the
  /// deposit. `multiplierX100` of 150 means 1.5x. No commission is taken on it.
  static int lateFee({
    required int dailyPrice,
    required int lateDays,
    required int multiplierX100,
    required int deposit,
  }) {
    if (lateDays <= 0) return 0;
    final raw = (dailyPrice * lateDays * multiplierX100 + 50) ~/ 100;
    return raw > deposit ? deposit : raw;
  }
}
