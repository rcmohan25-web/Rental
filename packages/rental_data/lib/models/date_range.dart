import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

/// An inclusive range of calendar days. Used for blocked dates.
class DateRange extends Equatable {
  DateRange(DateTime start, DateTime end)
      : start = dateOnly(start),
        end = dateOnly(end);

  factory DateRange.fromJson(Map<String, dynamic> json) => DateRange(
        parseDate(json['start_date']),
        parseDate(json['end_date']),
      );

  final DateTime start;
  final DateTime end;

  Map<String, dynamic> toJson() => {
        'start_date': formatDate(start),
        'end_date': formatDate(end),
      };

  /// True when this range shares at least one day with [otherStart]..[otherEnd].
  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    final s = dateOnly(otherStart);
    final e = dateOnly(otherEnd);
    return !s.isAfter(end) && !e.isBefore(start);
  }

  @override
  List<Object?> get props => [start, end];
}
