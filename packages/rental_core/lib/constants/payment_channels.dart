/// Manual payment channels accepted by Sapati. The Borrower pays the company
/// account by scanning a static QR code that ships with the app
/// (see apps/mobile/assets/payment_qr/README.md).
enum PaymentChannel {
  esewa('eSewa', 'assets/payment_qr/esewa.png'),
  khalti('Khalti', 'assets/payment_qr/khalti.png'),
  bank('Bank transfer', 'assets/payment_qr/bank.png');

  const PaymentChannel(this.label, this.qrAsset);

  /// Name shown in the UI.
  final String label;

  /// Asset path of the static QR image (use an errorBuilder when showing it).
  final String qrAsset;
}
