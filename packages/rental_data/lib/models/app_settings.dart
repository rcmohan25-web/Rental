import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

/// The admin-edited settings. In the database they are rows of `app_settings`
/// (`key text`, `value jsonb`) with the names the team contract fixes:
/// `commission_rate`, `deposit_rate`, `min_deposit_amount`,
/// `late_fee_multiplier`, `return_grace_hours`, `legal_action_period_days`,
/// `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`.
///
/// Contract v0.3 approves only three values: deposit 20%, commission 10% and
/// the 1.5x late-fee multiplier. Those three are required: a missing or
/// malformed one is an error, never a silent 0. The other six are admin-set
/// and not seeded by migrations, so they are optional here (null means "not
/// set"); a value that is present must still be valid.
///
/// `minDepositAmount` (whole NPR) is the fixed minimum deposit for low-value
/// items (supervisor decision 23 Nov 2026, contract v1.0 section 3.1).
class AppSettings extends Equatable {
  const AppSettings({
    required this.commissionRateBps,
    required this.depositRateBps,
    required this.lateFeeMultiplierX100,
    this.minDepositAmount,
    this.returnGraceHours,
    this.legalActionPeriodDays,
    this.requestExpiryHours,
    this.minDeclaredValue,
    this.autoApproveOrders,
  });

  /// Reads `key` to `value` pairs. Throws FormatException on a missing
  /// required key or an invalid value.
  factory AppSettings.fromKeyValues(Map<String, Object?> values) {
    Object need(String key) {
      final value = values[key];
      if (value == null) throw FormatException('Missing setting: $key');
      return value;
    }

    int? optionalWhole(String key) {
      final value = values[key];
      if (value == null) return null;
      if (value is! num || value != value.roundToDouble() || value < 0) {
        throw FormatException(
          'Setting $key must be a whole number, zero or more: $value',
        );
      }
      return value.toInt();
    }

    final multiplier = need('late_fee_multiplier');
    if (multiplier is! num) {
      throw const FormatException(
        'Setting late_fee_multiplier must be a number',
      );
    }
    final auto = values['auto_approve_orders'];
    if (auto != null && auto is! bool) {
      throw const FormatException(
        'Setting auto_approve_orders must be true or false',
      );
    }
    return AppSettings(
      commissionRateBps: rateToBps(need('commission_rate')),
      depositRateBps: rateToBps(need('deposit_rate')),
      lateFeeMultiplierX100: (multiplier * 100).round(),
      minDepositAmount: optionalWhole('min_deposit_amount'),
      returnGraceHours: optionalWhole('return_grace_hours'),
      legalActionPeriodDays: optionalWhole('legal_action_period_days'),
      requestExpiryHours: optionalWhole('request_expiry_hours'),
      minDeclaredValue: optionalWhole('min_declared_value'),
      autoApproveOrders: auto as bool?,
    );
  }

  /// Reads rows of the `app_settings` table.
  factory AppSettings.fromRows(Iterable<Map<String, dynamic>> rows) =>
      AppSettings.fromKeyValues({
        for (final row in rows) row['key'] as String: row['value'],
      });

  /// The three values approved in contract v0.3, for the fakes and tests.
  /// The settings an admin sets stay null on purpose.
  static const AppSettings fakeDefaults = AppSettings(
    commissionRateBps: 1000,
    depositRateBps: 2000,
    lateFeeMultiplierX100: 150,
  );

  /// Basis points: 1000 = 10%.
  final int commissionRateBps;

  /// Basis points: 2000 = 20% of the declared value.
  final int depositRateBps;

  /// x100: 150 = 1.5x.
  final int lateFeeMultiplierX100;

  /// Whole NPR. The deposit is never below this. Null = not set (the server
  /// then refuses new requests with SETTING_UNAVAILABLE).
  final int? minDepositAmount;

  /// Admin-set (null = not set).
  final int? returnGraceHours;

  /// Admin-set (null = not set).
  final int? legalActionPeriodDays;

  /// Admin-set (null = not set).
  final int? requestExpiryHours;

  /// Admin-set (null = not set).
  final int? minDeclaredValue;

  /// Admin-set (null = not set).
  final bool? autoApproveOrders;

  /// The same pairs the database holds (fractions, not basis points). Settings
  /// that are not set are left out.
  Map<String, Object?> toKeyValues() => {
        'commission_rate': bpsToRate(commissionRateBps),
        'deposit_rate': bpsToRate(depositRateBps),
        'late_fee_multiplier': lateFeeMultiplierX100 / 100,
        if (minDepositAmount != null) 'min_deposit_amount': minDepositAmount,
        if (returnGraceHours != null) 'return_grace_hours': returnGraceHours,
        if (legalActionPeriodDays != null)
          'legal_action_period_days': legalActionPeriodDays,
        if (requestExpiryHours != null)
          'request_expiry_hours': requestExpiryHours,
        if (minDeclaredValue != null) 'min_declared_value': minDeclaredValue,
        if (autoApproveOrders != null) 'auto_approve_orders': autoApproveOrders,
      };

  @override
  List<Object?> get props => [
        commissionRateBps,
        depositRateBps,
        lateFeeMultiplierX100,
        minDepositAmount,
        returnGraceHours,
        legalActionPeriodDays,
        requestExpiryHours,
        minDeclaredValue,
        autoApproveOrders,
      ];
}
