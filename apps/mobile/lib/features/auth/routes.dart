import 'package:go_router/go_router.dart';

import 'presentation/auth_screen.dart';

/// Routes of the auth feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> authRoutes = [
  GoRoute(
    path: '/auth',
    builder: (context, state) => const AuthScreen(),
  ),
];
