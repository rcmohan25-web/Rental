import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

import '../application/admin_providers.dart';
import 'admin_side_nav.dart';

/// Layout for every admin screen: side navigation plus content.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final nav = AdminSideNav(location: location);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.adminTitle),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(adminAuthRepositoryProvider).signOut(),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: nav),
      body: Row(
        children: [
          if (wide) ...[
            SizedBox(width: 260, child: nav),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}
