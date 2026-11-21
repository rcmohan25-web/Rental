import 'package:go_router/go_router.dart';

import 'presentation/users_screen.dart';

/// Routes of the users feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> usersRoutes = [
  GoRoute(
    path: '/users',
    builder: (context, state) => const UsersScreen(),
  ),
];
