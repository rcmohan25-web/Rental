import 'package:go_router/go_router.dart';

import 'presentation/explore_screen.dart';

/// Routes of the explore feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> exploreRoutes = [
  GoRoute(
    path: '/explore',
    builder: (context, state) => const ExploreScreen(),
  ),
];
