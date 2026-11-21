import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_core/rental_core.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

const List<_Destination> _destinations = [
  _Destination('Overview', Icons.dashboard_outlined, '/'),
  _Destination('Users', Icons.people_outline, '/users'),
  _Destination('ID verification queue', Icons.badge_outlined, '/kyc'),
  _Destination('Orders', Icons.receipt_long_outlined, '/orders'),
  _Destination('Payment verification', Icons.payments_outlined, '/payments'),
  _Destination(
    'Settlement and ledger',
    Icons.account_balance_wallet_outlined,
    '/settlement',
  ),
  _Destination('Disputes', Icons.gavel_outlined, '/disputes'),
  _Destination('Terms manager', Icons.description_outlined, '/terms'),
  _Destination('Platform settings', Icons.tune, '/settings'),
  _Destination('Analytics', Icons.bar_chart, '/analytics'),
  _Destination('Audit log', Icons.history, '/audit-log'),
];

/// Side navigation for the admin panel (a drawer on narrow screens).
class AdminSideNav extends StatelessWidget {
  const AdminSideNav({required this.location, super.key});

  /// Current route path, used to highlight the selected entry.
  final String location;

  bool _selected(String path) =>
      path == '/' ? location == '/' : location.startsWith(path);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              AppConstants.adminTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy,
              ),
            ),
          ),
          for (final d in _destinations)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.label),
              selected: _selected(d.path),
              selectedColor: BrandColors.navy,
              selectedTileColor: BrandColors.background,
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                context.go(d.path);
              },
            ),
        ],
      ),
    );
  }
}
