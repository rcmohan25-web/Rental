// Enums shared by the models. `wire` is the exact string used by Postgres and
// JSON (snake_case). See docs/api-contract.md section 2.

enum UserRole {
  user('user'),
  admin('admin');

  const UserRole(this.wire);
  final String wire;

  static UserRole fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown UserRole: $value'),
      );
}

enum AccountStatus {
  active('active'),
  suspended('suspended'),
  deleted('deleted');

  const AccountStatus(this.wire);
  final String wire;

  static AccountStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown AccountStatus: $value'),
      );
}

enum KycStatus {
  none('none'),
  pending('pending'),
  verified('verified'),
  rejected('rejected');

  const KycStatus(this.wire);
  final String wire;

  static KycStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown KycStatus: $value'),
      );
}

enum Area {
  kathmandu('kathmandu', 'Kathmandu'),
  lalitpur('lalitpur', 'Lalitpur'),
  bhaktapur('bhaktapur', 'Bhaktapur');

  const Area(this.wire, this.label);
  final String wire;

  /// Text shown in the UI.
  final String label;

  static Area fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown Area: $value'),
      );

  /// `items.pickup_area` is free text ("Jawalakhel Chowk, Lalitpur"). Returns
  /// the valley area it mentions, or null when it names none of the three.
  static Area? fromText(String text) {
    final lower = text.toLowerCase();
    for (final area in values) {
      if (lower.contains(area.wire)) return area;
    }
    return null;
  }
}

/// `items.status` in the committed schema.
enum ItemStatus {
  draft('draft'),
  active('active'),
  paused('paused');

  const ItemStatus(this.wire);
  final String wire;

  static ItemStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown ItemStatus: $value'),
      );
}

/// `terms_documents.status` in the committed schema.
enum TermsStatus {
  draft('draft'),
  published('published'),
  archived('archived');

  const TermsStatus(this.wire);
  final String wire;

  static TermsStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown TermsStatus: $value'),
      );
}

enum TermsAudience {
  general('general'),
  borrower('borrower'),
  renter('renter');

  const TermsAudience(this.wire);
  final String wire;

  static TermsAudience fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown TermsAudience: $value'),
      );
}

/// Booking lifecycle. Only RPCs change it (docs/api-contract.md section 5).
enum BookingStatus {
  requested('requested'),
  declined('declined'),
  expired('expired'),
  cancelled('cancelled'),
  renterAccepted('renter_accepted'),
  awaitingPayment('awaiting_payment'),
  paymentSubmitted('payment_submitted'),
  paymentVerified('payment_verified'),
  handedOver('handed_over'),
  returned('returned'),
  completed('completed'),
  disputed('disputed');

  const BookingStatus(this.wire);
  final String wire;

  /// True while the booking holds the item's dates. Must match the committed
  /// GiST constraint `prevent_double_booking` (api-contract section 2.1):
  /// renter_accepted through disputed block; requested, declined, expired,
  /// cancelled and completed do not.
  bool get blocksDates => switch (this) {
        BookingStatus.renterAccepted ||
        BookingStatus.awaitingPayment ||
        BookingStatus.paymentSubmitted ||
        BookingStatus.paymentVerified ||
        BookingStatus.handedOver ||
        BookingStatus.returned ||
        BookingStatus.disputed =>
          true,
        _ => false,
      };

  /// The Borrower may cancel before payment (transition 2c).
  bool get borrowerCanCancel => switch (this) {
        BookingStatus.requested ||
        BookingStatus.renterAccepted ||
        BookingStatus.awaitingPayment =>
          true,
        _ => false,
      };

  /// No further transitions happen after these.
  bool get isFinished => switch (this) {
        BookingStatus.declined ||
        BookingStatus.expired ||
        BookingStatus.cancelled ||
        BookingStatus.completed =>
          true,
        _ => false,
      };

  static BookingStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown BookingStatus: $value'),
      );
}

enum PaymentStatus {
  submitted('submitted'),
  verified('verified'),
  rejected('rejected');

  const PaymentStatus(this.wire);
  final String wire;

  static PaymentStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown PaymentStatus: $value'),
      );
}

enum LedgerEntryType {
  rentalFee('rental_fee'),
  commission('commission'),
  renterEarning('renter_earning'),
  lateFee('late_fee'),
  damageDeduction('damage_deduction'),
  depositRefund('deposit_refund'),
  claimRecoverable('claim_recoverable');

  const LedgerEntryType(this.wire);
  final String wire;

  static LedgerEntryType fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown LedgerEntryType: $value'),
      );
}

enum LedgerStatus {
  onHold('on_hold'),
  due('due'),
  paid('paid'),
  cancelled('cancelled');

  const LedgerStatus(this.wire);
  final String wire;

  static LedgerStatus fromWire(String value) => values.firstWhere(
        (e) => e.wire == value,
        orElse: () => throw FormatException('Unknown LedgerStatus: $value'),
      );
}
