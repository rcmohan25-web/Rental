import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

// The ONE place where the app chooses which repositories the Borrower screens
// use. Items and settings come from RentalBackend: the Supabase repositories
// when the app has SUPABASE_URL and the anon key, the in-memory fakes otherwise.
//
// Bookings stay on the in-memory fake until Phase 2 (create_booking_request is
// in the database, but the Borrower cannot read blocked dates or the booking
// list yet: get_blocked_dates and the booking reads are planned). So while the
// backend is live the "Send rental request" button is switched off instead of
// pretending to send (see bookingRequestsEnabledProvider).

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => RentalBackend.settings(),
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => RentalBackend.items(),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FakeBookingRepository(
    items: ref.watch(itemRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    latency: const Duration(milliseconds: 400),
  ),
);

/// False while the real backend is connected and the booking repository is
/// still a fake. Phase 2 changes this to true and removes the notice.
final bookingRequestsEnabledProvider = Provider<bool>(
  (ref) => !RentalBackend.isLive,
);
