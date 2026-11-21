import 'package:go_router/go_router.dart';

import 'presentation/renter_listings_screen.dart';

/// Routes of the renter_listings feature (owner: Srijan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> renterListingsRoutes = [
  GoRoute(
    path: '/listings',
    builder: (context, state) => const RenterListingsScreen(),
  ),
];
