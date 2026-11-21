import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route guard for the admin panel.
/// TODO(Mohan, Phase 1): return '/login' unless the session user has
/// profiles.role = 'admin'. Until then every route is open (skeleton only).
String? adminRedirect(BuildContext context, GoRouterState state) => null;
