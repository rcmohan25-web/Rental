import 'package:go_router/go_router.dart';

import 'presentation/audit_log_screen.dart';

/// Routes of the audit_log feature (owner: Smaran).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> auditLogRoutes = [
  GoRoute(
    path: '/audit-log',
    builder: (context, state) => const AuditLogScreen(),
  ),
];
