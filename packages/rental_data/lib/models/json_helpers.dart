// Small helpers so every model reads and writes dates and money the same way.
// Not exported from the package; only the models import this file.

import 'package:rental_core/rental_core.dart' show Money;

/// Reads a money column (`numeric(12,2)` arrives as a JSON number) as whole
/// NPR. A value with paise (3500.50) is refused: amounts must be whole NPR.
int wholeNpr(Object? value) {
  if (value is! num) throw FormatException('Money must be a number: $value');
  if (value != value.roundToDouble()) {
    throw FormatException('Money must be whole NPR: $value');
  }
  return value.toInt();
}

/// Reads a rate column (`numeric(5,4)` fraction such as 0.10) as basis points.
int rateToBps(Object? value) {
  if (value is! num) throw FormatException('Rate must be a number: $value');
  return Money.bpsFromRate(value);
}

/// Writes basis points as the database fraction.
double bpsToRate(int bps) => Money.rateFromBps(bps);

/// Parses a `date` column ('2026-11-06') into a local date-only DateTime.
DateTime parseDate(Object? value) {
  final text = value as String;
  final parts = text.split('-');
  if (parts.length < 3) throw FormatException('Bad date: $text');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2].substring(0, 2)),
  );
}

/// Writes a date-only value as 'YYYY-MM-DD'.
String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a `timestamptz` value (ISO 8601).
DateTime parseTimestamp(Object? value) => DateTime.parse(value as String);

DateTime? parseTimestampOrNull(Object? value) =>
    value == null ? null : parseTimestamp(value);

/// Writes a timestamp as ISO 8601 in UTC.
String formatTimestamp(DateTime value) => value.toUtc().toIso8601String();

/// Strips the time of day.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
