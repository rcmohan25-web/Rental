import 'package:go_router/go_router.dart';

import 'presentation/notifications_screen.dart';

/// Routes of the notifications feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> notificationsRoutes = [
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationsScreen(),
  ),
];
