import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_core/rental_core.dart';

import '../features/users/routes.dart';
import '../features/kyc_queue/routes.dart';
import '../features/orders/routes.dart';
import '../features/payments/routes.dart';
import '../features/settlement/routes.dart';
import '../features/disputes/routes.dart';
import '../features/terms_manager/routes.dart';
import '../features/settings/routes.dart';
import '../features/analytics/routes.dart';
import '../features/audit_log/routes.dart';
import '../features/shell/application/admin_guard.dart';
import '../features/shell/presentation/admin_shell.dart';

/// Every admin screen lives inside the shell (side navigation).
/// Keep this file thin: add paths in the feature's own routes.dart.
final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: adminRedirect,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PlaceholderView(
              title: 'Admin overview',
              owner: 'Mohan',
              description: 'Counts of pending IDs, payments and open cases.',
            ),
          ),
          ...usersRoutes,
          ...kycQueueRoutes,
          ...ordersRoutes,
          ...paymentsRoutes,
          ...settlementRoutes,
          ...disputesRoutes,
          ...termsManagerRoutes,
          ...settingsRoutes,
          ...analyticsRoutes,
          ...auditLogRoutes,
        ],
      ),
    ],
  );
});
