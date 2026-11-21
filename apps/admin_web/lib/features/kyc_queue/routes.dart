import 'package:go_router/go_router.dart';

import 'presentation/kyc_queue_screen.dart';

/// Routes of the kyc_queue feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> kycQueueRoutes = [
  GoRoute(
    path: '/kyc',
    builder: (context, state) => const KycQueueScreen(),
  ),
];
