import 'package:go_router/go_router.dart';

import 'presentation/borrower_bookings_screen.dart';

/// Routes of the borrower_bookings feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> borrowerBookingsRoutes = [
  GoRoute(
    path: '/bookings',
    builder: (context, state) => const BorrowerBookingsScreen(),
  ),
];
