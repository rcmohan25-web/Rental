/// All amounts are whole NPR. Rates are basis points (10% = 1000).
class MoneyBreakdown {
  const MoneyBreakdown({
    required this.days,
    required this.rentalFee,
    required this.deposit,
    required this.commission,
    required this.renterEarning,
  });

  final int days;
  final int rentalFee;
  final int deposit;
  final int commission;
  final int renterEarning;

  /// What the borrower pays in total (fee + refundable deposit).
  int get borrowerPays => rentalFee + deposit;
}

class Money {
  Money._();

  /// Inclusive day count: 6 Nov to 8 Nov = 3.
  static int days(DateTime start, DateTime end) {
    final s = DateTime.utc(start.year, start.month, start.day);
    final e = DateTime.utc(end.year, end.month, end.day);
    if (e.isBefore(s)) {
      throw ArgumentError('end date must not be before start date');
    }
    return e.difference(s).inDays + 1;
  }

  /// amount x rate, rounded half up to whole NPR.
  static int applyRate(int amount, int rateBps) {
    if (amount < 0 || rateBps < 0) {
      throw ArgumentError('amount and rate must not be negative');
    }
    return (amount * rateBps + 5000) ~/ 10000;
  }

  static int rentalFee(int days, int dailyPrice) {
    if (days < 1 || dailyPrice < 1) {
      throw ArgumentError('days and daily price must be at least 1');
    }
    return days * dailyPrice;
  }

  static int deposit(int declaredValue, int depositRateBps) =>
      applyRate(declaredValue, depositRateBps);

  static MoneyBreakdown breakdown({
    required DateTime start,
    required DateTime end,
    required int dailyPrice,
    required int declaredValue,
    required int depositRateBps,
    required int commissionRateBps,
  }) {
    final d = days(start, end);
    final fee = rentalFee(d, dailyPrice);
    final commission = applyRate(fee, commissionRateBps);
    return MoneyBreakdown(
      days: d,
      rentalFee: fee,
      deposit: deposit(declaredValue, depositRateBps),
      commission: commission,
      renterEarning: fee - commission,
    );
  }

  /// Whole days late after the grace period; any part of a day counts as 1.
  static int lateDays(DateTime endDate, DateTime returnedAt, int graceHours) {
    final deadline = DateTime(endDate.year, endDate.month, endDate.day + 1)
        .add(Duration(hours: graceHours));
    if (!returnedAt.isAfter(deadline)) return 0;
    final minutesLate = returnedAt.difference(deadline).inMinutes;
    return (minutesLate + 1439) ~/ 1440; // ceiling division
  }

  /// multiplierX100: 150 means 1.5x. Never more than the deposit.
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