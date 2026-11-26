import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_helpers.dart';

/// One row of `ledger_entries`. Amounts are positive whole NPR; the direction
/// is given by [entryType]. Only admins change [status] (through RPCs).
class LedgerEntry extends Equatable {
  const LedgerEntry({
    required this.id,
    required this.bookingId,
    required this.entryType,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.userId,
    this.note,
    this.paidReference,
    this.paidAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        userId: json['user_id'] as String?,
        entryType: LedgerEntryType.fromWire(json['entry_type'] as String),
        amount: json['amount'] as int,
        status: LedgerStatus.fromWire(json['status'] as String),
        note: json['note'] as String?,
        paidReference: json['paid_reference'] as String?,
        createdAt: parseTimestamp(json['created_at']),
        paidAt: parseTimestampOrNull(json['paid_at']),
      );

  final String id;
  final String bookingId;

  /// Who the money is due to or from.
  final String? userId;
  final LedgerEntryType entryType;
  final int amount;
  final LedgerStatus status;
  final String? note;

  /// Offline payout or refund reference recorded by an admin.
  final String? paidReference;
  final DateTime createdAt;
  final DateTime? paidAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'user_id': userId,
        'entry_type': entryType.wire,
        'amount': amount,
        'status': status.wire,
        'note': note,
        'paid_reference': paidReference,
        'created_at': formatTimestamp(createdAt),
        'paid_at': paidAt == null ? null : formatTimestamp(paidAt!),
      };

  @override
  List<Object?> get props => [
        id,
        bookingId,
        userId,
        entryType,
        amount,
        status,
        note,
        paidReference,
        createdAt,
        paidAt,
      ];
}
