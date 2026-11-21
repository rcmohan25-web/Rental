import 'package:go_router/go_router.dart';

import 'presentation/settings_screen.dart';

/// Routes of the settings feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsScreen(),
  ),
];
