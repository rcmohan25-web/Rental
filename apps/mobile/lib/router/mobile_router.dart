import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/routes.dart';
import '../features/profile_kyc/routes.dart';
import '../features/explore/routes.dart';
import '../features/item_details/routes.dart';
import '../features/borrower_bookings/routes.dart';
import '../features/notifications/routes.dart';
import '../features/reviews/routes.dart';
import '../features/renter_listings/routes.dart';
import '../features/renter_inbox/routes.dart';
import '../features/renter_handover_return/routes.dart';
import '../features/renter_earnings/routes.dart';
import '../skeleton/skeleton_home_screen.dart';

/// Aggregates the route list of every feature. Keep this file thin:
/// add paths in the feature's own routes.dart, not here.
final mobileRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // TODO(Mohan, Phase 1): redirect for auth guard and the ID gate.
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SkeletonHomeScreen(),
      ),
      ...authRoutes,
      ...profileKycRoutes,
      ...exploreRoutes,
      ...itemDetailsRoutes,
      ...borrowerBookingsRoutes,
      ...notificationsRoutes,
      ...reviewsRoutes,
      ...renterListingsRoutes,
      ...renterInboxRoutes,
      ...renterHandoverReturnRoutes,
      ...renterEarningsRoutes,
    ],
  );
});
