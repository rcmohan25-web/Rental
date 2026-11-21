import 'package:go_router/go_router.dart';

import 'presentation/reviews_screen.dart';

/// Routes of the reviews feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> reviewsRoutes = [
  GoRoute(
    path: '/reviews',
    builder: (context, state) => const ReviewsScreen(),
  ),
];
