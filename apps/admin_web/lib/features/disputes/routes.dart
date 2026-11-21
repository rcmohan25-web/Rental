import 'package:go_router/go_router.dart';

import 'presentation/disputes_screen.dart';

/// Routes of the disputes feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> disputesRoutes = [
  GoRoute(
    path: '/disputes',
    builder: (context, state) => const DisputesScreen(),
  ),
];
