import 'package:go_router/go_router.dart';

import 'presentation/renter_inbox_screen.dart';

/// Routes of the renter_inbox feature (owner: Srijan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> renterInboxRoutes = [
  GoRoute(
    path: '/inbox',
    builder: (context, state) => const RenterInboxScreen(),
  ),
];
