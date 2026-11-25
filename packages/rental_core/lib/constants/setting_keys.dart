/// Keys of the app_settings table (plan Section 4.3 plus the minimum deposit
/// decided with the supervisor). The values are set by an admin and are never
/// hard-coded in the apps.
abstract final class SettingKeys {
  static const String commissionRate = 'commission_rate';
  static const String depositRate = 'deposit_rate';

  /// Fixed minimum security deposit in NPR, used for low-value products.
  static const String minDepositAmount = 'min_deposit_amount';
  static const String lateFeeMultiplier = 'late_fee_multiplier';
  static const String returnGraceHours = 'return_grace_hours';
  static const String legalActionPeriodDays = 'legal_action_period_days';
  static const String requestExpiryHours = 'request_expiry_hours';
  static const String minDeclaredValue = 'min_declared_value';
  static const String autoApproveOrders = 'auto_approve_orders';

  static const List<String> all = [
    commissionRate,
    depositRate,
    minDepositAmount,
    lateFeeMultiplier,
    returnGraceHours,
    legalActionPeriodDays,
    requestExpiryHours,
    minDeclaredValue,
    autoApproveOrders,
  ];
}
