import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/routes.dart';
import '../features/borrower_bookings/routes.dart';
import '../features/explore/routes.dart';
import '../features/item_details/routes.dart';
import '../features/notifications/routes.dart';
import '../features/profile_kyc/routes.dart';
import '../features/renter_earnings/routes.dart';
import '../features/renter_handover_return/routes.dart';
import '../features/renter_inbox/routes.dart';
import '../features/renter_listings/routes.dart';
import '../features/reviews/routes.dart';
import '../shared/main_shell.dart';

/// Aggregates the route list of every feature. Keep this file thin:
/// add paths in the feature's own routes.dart, not here.
final mobileRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: ref.watch(authRefreshProvider),
    redirect: (context, state) =>
        mobileRedirect(userId: auth.currentUserId, location: state.uri.path),
    routes: [
      ...authRoutes,
      // The four tab screens (and their sub-screens) share the bottom bar.
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          ...exploreRoutes,
          ...borrowerBookingsRoutes,
          ...renterListingsRoutes,
          ...profileKycRoutes,
        ],
      ),
      ...itemDetailsRoutes,
      ...notificationsRoutes,
      ...reviewsRoutes,
      ...renterInboxRoutes,
      ...renterHandoverReturnRoutes,
      ...renterEarningsRoutes,
    ],
  );
});
