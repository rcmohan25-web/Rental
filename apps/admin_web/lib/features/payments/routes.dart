import 'package:go_router/go_router.dart';

import 'presentation/payments_screen.dart';

/// Routes of the payments feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> paymentsRoutes = [
  GoRoute(
    path: '/payments',
    builder: (context, state) => const PaymentsScreen(),
  ),
];
