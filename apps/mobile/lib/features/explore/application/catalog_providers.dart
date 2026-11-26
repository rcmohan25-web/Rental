import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

// The ONE place where the app chooses which repositories to use.
// Phase 0 uses the in-memory fakes. When Srijan's Supabase repositories land,
// change these three providers (nothing else) and every screen switches over.

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FakeSettingsRepository(),
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => FakeItemRepository(latency: const Duration(milliseconds: 400)),
);

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => FakeBookingRepository(
    items: ref.watch(itemRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    latency: const Duration(milliseconds: 400),
  ),
);
