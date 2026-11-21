import 'package:go_router/go_router.dart';

import 'presentation/settlement_screen.dart';

/// Routes of the settlement feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> settlementRoutes = [
  GoRoute(
    path: '/settlement',
    builder: (context, state) => const SettlementScreen(),
  ),
];
