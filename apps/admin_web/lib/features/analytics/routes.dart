import 'package:go_router/go_router.dart';

import 'presentation/analytics_screen.dart';

/// Routes of the analytics feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> analyticsRoutes = [
  GoRoute(
    path: '/analytics',
    builder: (context, state) => const AnalyticsScreen(),
  ),
];
