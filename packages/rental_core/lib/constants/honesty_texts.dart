/// Wording required by the honesty rules (plan Section 2).
/// Show these in the app exactly as written.
abstract final class HonestyTexts {
  static const String manualPayment = 'Manual payment (prototype)';
  static const String manualPaymentDetail =
      'You pay the platform outside the app (eSewa, Khalti or bank transfer) '
      'and upload proof. An admin verifies it. There is no payment gateway, '
      'escrow or insurance.';

  /// Shown above the static Sapati QR codes on the payment screen.
  static const String paymentQrInstruction =
      'Scan the Sapati QR code for eSewa, Khalti or bank transfer. Pay the '
      'exact total, then upload the screenshot and the payment reference.';
  static const String payoutsRecorded =
      'Payouts and refunds are recorded here, but paid outside the app by an '
      'admin.';
  static const String identityManual =
      'Verified means checked by an admin. No automatic face matching is used.';
  static const String termsTemplate =
      'Prototype terms, not legal advice. Sapati\'s legal team reviews the '
      'wording before real use.';
  static const String tickIsAcceptance =
      'Ticking this box records your acceptance. It is not a certified '
      'electronic signature.';
  static const String appliesToNewRequests =
      'Applies to new requests from now on.';

  /// Shown at ID upload and at handover (template wording, no specific law
  /// until Sapati's legal team confirms it).
  static const String idMisuseWarning =
      'Using another person\'s ID, submitting a false or altered document or '
      'photo, or letting someone else use your verified account is misuse of '
      'identity. It can lead to account suspension and may be punishable '
      'according to the law.';

  static const String idConsentNotice =
      'Your ID photo is stored privately. Only Sapati admins can see it, to '
      'check your identity. It is kept only as long as needed for that check '
      'and for any open case.';
}
