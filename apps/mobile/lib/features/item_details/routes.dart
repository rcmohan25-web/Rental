import 'package:go_router/go_router.dart';

import 'presentation/item_details_screen.dart';

/// Routes of the item_details feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> itemDetailsRoutes = [
  // Kept so the Phase 0 skeleton link keeps working.
  GoRoute(
    path: '/item-details',
    builder: (context, state) => const ItemDetailsScreen(),
  ),
  GoRoute(
    path: '/item-details/:id',
    builder: (context, state) =>
        ItemDetailsScreen(itemId: state.pathParameters['id']),
  ),
];
