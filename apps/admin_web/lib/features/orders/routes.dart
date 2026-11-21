import 'package:go_router/go_router.dart';

import 'presentation/orders_screen.dart';

/// Routes of the orders feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> ordersRoutes = [
  GoRoute(
    path: '/orders',
    builder: (context, state) => const OrdersScreen(),
  ),
];
