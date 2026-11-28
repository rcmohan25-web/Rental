import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

/// The one place the renter_listings feature picks its repository.
final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => RentalBackend.listings(),
);

/// The signed-in Renter's items (draft, active, paused). Invalidate after
/// any change.
final myItemsProvider = FutureProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(listingRepositoryProvider).listMyItems(),
);
