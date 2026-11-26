import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_helpers.dart';

/// One row of `profiles`. The committed schema only has `display_name`,
/// `created_at` and `updated_at`; every other field is a plan-required column
/// that is still to be migrated (docs/api-contract.md section 2.2), so it is
/// optional or has a least-privilege default when the column is missing.
/// The ID photo path is never part of this model.
class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.createdAt,
    this.area,
    this.role = UserRole.user,
    this.accountStatus = AccountStatus.active,
    this.kycStatus = KycStatus.none,
    this.phone,
    this.avatarUrl,
    this.kycRejectReason,
    this.payoutDetails,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final display = json['display_name'] as String?;
    final full = (json['full_name'] as String?) ?? display ?? '';
    final trimmed = full.trim();
    final first = (json['first_name'] as String?) ??
        (trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first);
    return Profile(
      id: json['id'] as String,
      fullName: full,
      firstName: first,
      phone: json['phone'] as String?,
      area: json['area'] == null ? null : Area.fromWire(json['area'] as String),
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] == null
          ? UserRole.user
          : UserRole.fromWire(json['role'] as String),
      accountStatus: json['account_status'] == null
          ? AccountStatus.active
          : AccountStatus.fromWire(json['account_status'] as String),
      kycStatus: json['kyc_status'] == null
          ? KycStatus.none
          : KycStatus.fromWire(json['kyc_status'] as String),
      kycRejectReason: json['kyc_reject_reason'] as String?,
      payoutDetails: json['payout_details'] as String?,
      createdAt: parseTimestamp(json['created_at']),
    );
  }

  final String id;

  /// Read from `full_name`, or from `display_name` until a migration adds it.
  final String fullName;

  /// Shown to the other party before payment is verified.
  final String firstName;

  /// Hidden from the other party until the booking is payment_verified.
  final String? phone;
  final Area? area;
  final String? avatarUrl;

  /// Not writable by the user.
  final UserRole role;

  /// Not writable by the user.
  final AccountStatus accountStatus;

  /// Not writable by the user.
  final KycStatus kycStatus;
  final String? kycRejectReason;

  /// Visible only to the account owner and admins.
  final String? payoutDetails;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isActive => accountStatus == AccountStatus.active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': fullName,
        'full_name': fullName,
        'first_name': firstName,
        'phone': phone,
        'area': area?.wire,
        'avatar_url': avatarUrl,
        'role': role.wire,
        'account_status': accountStatus.wire,
        'kyc_status': kycStatus.wire,
        'kyc_reject_reason': kycRejectReason,
        'payout_details': payoutDetails,
        'created_at': formatTimestamp(createdAt),
      };

  @override
  List<Object?> get props => [
        id,
        fullName,
        firstName,
        phone,
        area,
        avatarUrl,
        role,
        accountStatus,
        kycStatus,
        kycRejectReason,
        payoutDetails,
        createdAt,
      ];
}
