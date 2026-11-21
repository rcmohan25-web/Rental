import 'package:go_router/go_router.dart';

import 'presentation/terms_manager_screen.dart';

/// Routes of the terms_manager feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> termsManagerRoutes = [
  GoRoute(
    path: '/terms',
    builder: (context, state) => const TermsManagerScreen(),
  ),
];
