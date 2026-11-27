import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

const List<_Tab> _tabs = [
  _Tab('Explore', Icons.search, '/explore'),
  _Tab('Bookings', Icons.receipt_long_outlined, '/bookings'),
  _Tab('Listings', Icons.inventory_2_outlined, '/listings'),
  _Tab('Profile', Icons.person_outline, '/profile'),
];

/// Bottom navigation for the signed-in app. The bar only shows on the four
/// tab screens, so forms and detail screens get the full height.
class MainShell extends StatelessWidget {
  const MainShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => t.path == location);
    return Scaffold(
      body: child,
      bottomNavigationBar: index == -1
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i].path),
              destinations: [
                for (final t in _tabs)
                  NavigationDestination(icon: Icon(t.icon), label: t.label),
              ],
            ),
    );
  }
}
