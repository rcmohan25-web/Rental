import 'package:go_router/go_router.dart';

import 'presentation/item_details_screen.dart';

/// Routes of the item_details feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> itemDetailsRoutes = [
  GoRoute(
    path: '/item-details',
    builder: (context, state) => const ItemDetailsScreen(),
  ),
];
