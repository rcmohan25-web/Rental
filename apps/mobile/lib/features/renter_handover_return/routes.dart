import 'package:go_router/go_router.dart';

import 'presentation/renter_handover_return_screen.dart';

/// Routes of the renter_handover_return feature (owner: Srijan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> renterHandoverReturnRoutes = [
  GoRoute(
    path: '/handover',
    builder: (context, state) => const RenterHandoverReturnScreen(),
  ),
];
