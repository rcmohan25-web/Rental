import '../../models/models.dart';

/// Realistic Kathmandu Valley sample data for UI work. Fake or consented data
/// only (docs/honesty-rules.md). Photos are placeholders from picsum.photos.
abstract final class FakeData {
  /// The signed-in Borrower in the fakes.
  static const String borrowerId = 'user-borrower-1';

  /// Another Borrower, used for a booking that blocks dates.
  static const String otherBorrowerId = 'user-borrower-2';

  static const String lenderAayushId = 'user-lender-1';
  static const String lenderPrasantaId = 'user-lender-2';
  static const String lenderSitaId = 'user-lender-3';

  /// Ids of the published terms documents a booking snapshots.
  static const List<String> termsVersionIds = [
    'terms-general-v1',
    'terms-borrower-v1',
    'terms-renter-v1',
  ];

  /// The camera of the plan's worked example is [items] index 0.
  static final List<Item> items = [
    _item(
      1,
      lender: lenderPrasantaId,
      lenderName: 'Prasanta',
      category: 'Cameras',
      title: 'Sony Alpha A7 III Camera',
      description:
          'Full-frame mirrorless camera with a 28-70mm lens, two batteries and '
          'a 64 GB card. Great for events and travel.',
      condition: 'Like new',
      declaredValue: 160000,
      dailyPrice: 3500,
      pickupArea: 'Jawalakhel Chowk, Lalitpur',
      rules: 'Collect and return in person at Jawalakhel. No underwater use.',
    ),
    _item(
      2,
      lender: lenderSitaId,
      lenderName: 'Sita',
      category: 'Cameras',
      title: 'Canon EOS 90D with 18-135mm lens',
      description: 'DSLR kit with bag, charger and one battery.',
      condition: 'Good',
      declaredValue: 120000,
      dailyPrice: 2500,
      pickupArea: 'Baneshwor, Kathmandu',
    ),
    _item(
      3,
      lender: lenderPrasantaId,
      lenderName: 'Prasanta',
      category: 'Projectors',
      title: 'Epson Full HD Projector',
      description: 'Bright 3,600 lumen projector. HDMI cable and screen stand '
          'included.',
      condition: 'Good',
      declaredValue: 70000,
      dailyPrice: 1800,
      pickupArea: 'Koteshwor, Kathmandu',
    ),
    _item(
      4,
      lender: lenderAayushId,
      lenderName: 'Aayush',
      category: 'Gaming consoles',
      title: 'PlayStation 5 Console',
      description: 'Disc edition with two controllers and three games.',
      condition: 'Like new',
      declaredValue: 90000,
      dailyPrice: 2000,
      pickupArea: 'Bhaktapur Durbar Square, Bhaktapur',
    ),
    _item(
      5,
      lender: lenderSitaId,
      lenderName: 'Sita',
      category: 'Gaming consoles',
      title: 'Nintendo Switch OLED',
      description: 'With dock, two Joy-Con controllers and a carry case.',
      condition: 'Good',
      declaredValue: 45000,
      dailyPrice: 1200,
      pickupArea: 'Patan, Lalitpur',
    ),
    _item(
      6,
      lender: lenderAayushId,
      lenderName: 'Aayush',
      category: 'Camping gear',
      title: '4-Person Camping Tent',
      description: 'Waterproof dome tent with rain fly and groundsheet.',
      condition: 'Good',
      declaredValue: 18000,
      dailyPrice: 600,
      pickupArea: 'Thamel, Kathmandu',
    ),
    _item(
      7,
      lender: lenderSitaId,
      lenderName: 'Sita',
      category: 'Camping gear',
      title: 'Hiking Backpack 65L',
      description: 'Comfortable trekking backpack with rain cover.',
      condition: 'Fair',
      declaredValue: 12000,
      dailyPrice: 400,
      pickupArea: 'Boudha, Kathmandu',
    ),
    _item(
      8,
      lender: lenderPrasantaId,
      lenderName: 'Prasanta',
      category: 'Tools',
      title: 'Bosch Cordless Drill Set',
      description: 'Drill driver with two batteries, charger and bit set.',
      condition: 'Good',
      declaredValue: 15000,
      dailyPrice: 500,
      pickupArea: 'Kupondole, Lalitpur',
    ),
    _item(
      9,
      lender: lenderAayushId,
      lenderName: 'Aayush',
      category: 'Musical instruments',
      title: 'Yamaha F310 Acoustic Guitar',
      description: 'Steel-string acoustic guitar with a padded bag and strap.',
      condition: 'Good',
      declaredValue: 25000,
      dailyPrice: 700,
      pickupArea: 'Suryabinayak, Bhaktapur',
    ),
    _item(
      10,
      lender: lenderSitaId,
      lenderName: 'Sita',
      category: 'Musical instruments',
      title: 'Casio Digital Piano 88 keys',
      description: 'Weighted keys, stand and sustain pedal included.',
      condition: 'Like new',
      declaredValue: 60000,
      dailyPrice: 1500,
      pickupArea: 'Lazimpat, Kathmandu',
    ),
    _item(
      11,
      lender: lenderPrasantaId,
      lenderName: 'Prasanta',
      category: 'Cameras',
      title: 'DJI Mini 3 Drone',
      description: 'Under 250 g drone with three batteries and a carry bag.',
      condition: 'Like new',
      declaredValue: 110000,
      dailyPrice: 3000,
      pickupArea: 'Pulchowk, Lalitpur',
      rules: 'Follow local drone rules. No flying near the airport.',
    ),
    _item(
      12,
      lender: lenderAayushId,
      lenderName: 'Aayush',
      category: 'Other',
      title: 'JBL PartyBox Speaker',
      description: 'Loud portable party speaker with lights and a microphone '
          'input.',
      condition: 'Good',
      declaredValue: 50000,
      dailyPrice: 1400,
      pickupArea: 'Maharajgunj, Kathmandu',
    ),
  ];

  /// A booking by another Borrower that blocks the camera for three days,
  /// starting five days from [today]. Lets the date picker show a clash.
  static List<Booking> seedBookings(DateTime today) {
    final start = DateTime(today.year, today.month, today.day + 5);
    final end = DateTime(today.year, today.month, today.day + 7);
    final created = DateTime.utc(2026, 11, 1);
    return [
      Booking(
        id: 'seed-booking-1',
        itemId: items.first.id,
        lenderId: items.first.lenderId,
        borrowerId: otherBorrowerId,
        startDate: start,
        endDate: end,
        status: BookingStatus.paymentVerified,
        days: 3,
        dailyPrice: 3500,
        declaredValue: 160000,
        rentalFee: 10500,
        deposit: 32000,
        commissionRateBps: 1000,
        depositRateBps: 2000,
        commissionAmount: 1050,
        renterEarning: 9450,
        lateFeeMultiplierX100: 150,
        returnGraceHours: 24,
        termsVersionIds: termsVersionIds,
        idempotencyKey: 'seed-key-1',
        createdAt: created,
        updatedAt: created,
      ),
    ];
  }

  static Item _item(
    int n, {
    required String lender,
    required String lenderName,
    required String category,
    required String title,
    required String description,
    required String condition,
    required int declaredValue,
    required int dailyPrice,
    required String pickupArea,
    String? rules,
  }) =>
      Item(
        id: 'item-$n',
        lenderId: lender,
        lenderFirstName: lenderName,
        category: category,
        title: title,
        description: description,
        condition: condition,
        declaredValue: declaredValue,
        dailyPrice: dailyPrice,
        pickupArea: pickupArea,
        photoUrls: [
          'https://picsum.photos/seed/rental-$n-a/800/600',
          'https://picsum.photos/seed/rental-$n-b/800/600',
        ],
        rules: rules,
        status: ItemStatus.active,
        // Higher n = older item, so item-1 is the newest.
        createdAt: DateTime.utc(2026, 11, 20).subtract(Duration(days: n)),
      );
}
