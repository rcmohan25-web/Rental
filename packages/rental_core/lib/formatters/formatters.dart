import 'package:intl/intl.dart';

/// NPR and date formatting. Dates are date-only, shown as the calendar day.
abstract final class Formatters {
  static final NumberFormat _npr = NumberFormat('#,##0', 'en_US');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');

  /// `formatNpr(10500)` gives `NPR 10,500`.
  static String npr(num amount) => 'NPR ${_npr.format(amount.round())}';

  /// `10 Jan 2027`.
  static String date(DateTime value) => _date.format(value);

  /// `10 Jan 2027, 3:30 PM`.
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// `10 Jan 2027 to 12 Jan 2027`.
  static String dateRange(DateTime start, DateTime end) =>
      '${date(start)} to ${date(end)}';
}
