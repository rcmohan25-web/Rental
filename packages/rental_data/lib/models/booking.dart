import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_helpers.dart';

/// One row of `bookings`. All money columns are snapshots taken by
/// `create_booking_request`; later changes to settings never alter them.
///
/// Dart keeps rates as basis points (exact integers). On the wire the team
/// contract uses fractions: `commission_rate` 0.1000, `deposit_rate` 0.2000.
/// JSON keys for the money snapshot follow the contract
/// (`agreed_daily_rate`, `rental_days`, `declared_value_snapshot`,
/// `rental_fee`, `deposit_amount`, `min_deposit_amount`, `commission_amount`,
/// `lender_earning`).
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.itemId,
    required this.lenderId,
    required this.borrowerId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.days,
    required this.dailyPrice,
    required this.declaredValue,
    required this.rentalFee,
    required this.deposit,
    required this.commissionRateBps,
    required this.depositRateBps,
    required this.commissionAmount,
    required this.renterEarning,
    required this.termsVersionIds,
    required this.createdAt,
    required this.updatedAt,
    this.minDepositAmount = 0,
    this.lateFeeMultiplierX100,
    this.returnGraceHours,
    this.idempotencyKey,
    this.declineReason,
    this.receiptConfirmedAt,
    this.isOverdue = false,
    this.isEscalated = false,
    this.hasDamageReport = false,
  });

  /// Only the columns of the committed schema are required. The snapshot and
  /// evidence columns are read when present.
  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        itemId: json['item_id'] as String,
        lenderId: json['lender_id'] as String,
        borrowerId: json['borrower_id'] as String,
        startDate: parseDate(json['start_date']),
        endDate: parseDate(json['end_date']),
        status: BookingStatus.fromWire(json['status'] as String),
        days: json['rental_days'] as int,
        dailyPrice: wholeNpr(json['agreed_daily_rate']),
        declaredValue: wholeNpr(json['declared_value_snapshot']),
        rentalFee: wholeNpr(json['rental_fee']),
        deposit: wholeNpr(json['deposit_amount']),
        commissionRateBps: rateToBps(json['commission_rate']),
        depositRateBps: rateToBps(json['deposit_rate']),
        minDepositAmount: json['min_deposit_amount'] == null
            ? 0
            : wholeNpr(json['min_deposit_amount']),
        commissionAmount: wholeNpr(json['commission_amount']),
        renterEarning: wholeNpr(json['lender_earning']),
        lateFeeMultiplierX100: json['late_fee_multiplier'] == null
            ? null
            : (((json['late_fee_multiplier'] as num) * 100).round()),
        returnGraceHours: json['return_grace_hours'] as int?,
        termsVersionIds: json['terms_version_ids'] == null
            ? const []
            : List<String>.from(json['terms_version_ids'] as List<dynamic>),
        declineReason: json['decline_reason'] as String?,
        receiptConfirmedAt: parseTimestampOrNull(json['receipt_confirmed_at']),
        isOverdue: (json['is_overdue'] as bool?) ?? false,
        isEscalated: (json['is_escalated'] as bool?) ?? false,
        hasDamageReport: (json['has_damage_report'] as bool?) ?? false,
        idempotencyKey: json['idempotency_key'] as String?,
        createdAt: parseTimestamp(json['created_at']),
        updatedAt: parseTimestamp(json['updated_at']),
      );

  final String id;
  final String itemId;

  /// The Renter.
  final String lenderId;
  final String borrowerId;

  /// Inclusive date range.
  final DateTime startDate;
  final DateTime endDate;
  final BookingStatus status;

  // Snapshots (whole NPR, rates in basis points).
  final int days;
  final int dailyPrice;
  final int declaredValue;
  final int rentalFee;
  final int deposit;
  final int commissionRateBps;
  final int depositRateBps;

  /// The minimum deposit that applied when the request was made (whole NPR).
  /// 0 for bookings created before the minimum existed.
  final int minDepositAmount;
  final int commissionAmount;
  final int renterEarning;

  /// Optional late-fee rule snapshot (x100). Null when not stored.
  final int? lateFeeMultiplierX100;
  final int? returnGraceHours;

  /// The committed schema stores `terms_version_ids uuid[]`; the relational
  /// snapshot is `booking_terms`.
  final List<String> termsVersionIds;
  final String? declineReason;

  /// Set by confirm_receipt; the status stays handed_over.
  final DateTime? receiptConfirmedAt;
  final bool isOverdue;
  final bool isEscalated;
  final bool hasDamageReport;

  /// Retry key of create_booking_request (planned in the contract).
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// What the Borrower pays in total (fee + refundable deposit).
  int get borrowerPays => rentalFee + deposit;

  /// Only the fields the fake repositories need to change.
  Booking copyWith({
    BookingStatus? status,
    String? declineReason,
    DateTime? updatedAt,
  }) =>
      Booking(
        id: id,
        itemId: itemId,
        lenderId: lenderId,
        borrowerId: borrowerId,
        startDate: startDate,
        endDate: endDate,
        status: status ?? this.status,
        days: days,
        dailyPrice: dailyPrice,
        declaredValue: declaredValue,
        rentalFee: rentalFee,
        deposit: deposit,
        commissionRateBps: commissionRateBps,
        depositRateBps: depositRateBps,
        minDepositAmount: minDepositAmount,
        commissionAmount: commissionAmount,
        renterEarning: renterEarning,
        lateFeeMultiplierX100: lateFeeMultiplierX100,
        returnGraceHours: returnGraceHours,
        termsVersionIds: termsVersionIds,
        declineReason: declineReason ?? this.declineReason,
        receiptConfirmedAt: receiptConfirmedAt,
        isOverdue: isOverdue,
        isEscalated: isEscalated,
        hasDamageReport: hasDamageReport,
        idempotencyKey: idempotencyKey,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'lender_id': lenderId,
        'borrower_id': borrowerId,
        'start_date': formatDate(startDate),
        'end_date': formatDate(endDate),
        'status': status.wire,
        'rental_days': days,
        'agreed_daily_rate': dailyPrice,
        'declared_value_snapshot': declaredValue,
        'rental_fee': rentalFee,
        'deposit_amount': deposit,
        'commission_rate': bpsToRate(commissionRateBps),
        'deposit_rate': bpsToRate(depositRateBps),
        'min_deposit_amount': minDepositAmount,
        'commission_amount': commissionAmount,
        'lender_earning': renterEarning,
        'late_fee_multiplier':
            lateFeeMultiplierX100 == null ? null : lateFeeMultiplierX100! / 100,
        'return_grace_hours': returnGraceHours,
        'terms_version_ids': termsVersionIds,
        'decline_reason': declineReason,
        'receipt_confirmed_at': receiptConfirmedAt == null
            ? null
            : formatTimestamp(receiptConfirmedAt!),
        'is_overdue': isOverdue,
        'is_escalated': isEscalated,
        'has_damage_report': hasDamageReport,
        'idempotency_key': idempotencyKey,
        'created_at': formatTimestamp(createdAt),
        'updated_at': formatTimestamp(updatedAt),
      };

  @override
  List<Object?> get props => [
        id,
        itemId,
        lenderId,
        borrowerId,
        startDate,
        endDate,
        status,
        days,
        dailyPrice,
        declaredValue,
        rentalFee,
        deposit,
        commissionRateBps,
        depositRateBps,
        minDepositAmount,
        commissionAmount,
        renterEarning,
        lateFeeMultiplierX100,
        returnGraceHours,
        termsVersionIds,
        declineReason,
        receiptConfirmedAt,
        isOverdue,
        isEscalated,
        hasDamageReport,
        idempotencyKey,
        createdAt,
        updatedAt,
      ];
}
