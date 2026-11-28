import 'package:go_router/go_router.dart';

import 'presentation/profile_kyc_screen.dart';
import 'presentation/verify_id_screen.dart';

/// Routes of the profile_kyc feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> profileKycRoutes = [
  GoRoute(
    path: '/profile',
    builder: (context, state) => const ProfileKycScreen(),
  ),
  GoRoute(
    path: '/profile/verify-id',
    builder: (context, state) => const VerifyIdScreen(),
  ),
];
