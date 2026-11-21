import 'package:go_router/go_router.dart';

import 'presentation/renter_earnings_screen.dart';

/// Routes of the renter_earnings feature (owner: Srijan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> renterEarningsRoutes = [
  GoRoute(
    path: '/earnings',
    builder: (context, state) => const RenterEarningsScreen(),
  ),
];
