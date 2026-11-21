import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_core/rental_core.dart';

/// TEMPORARY. Lists every placeholder screen so the skeleton can be clicked
/// through on an emulator. Delete this folder when the real auth and home
/// screens land (Mohan, Phase 1).
class SkeletonHomeScreen extends StatelessWidget {
  const SkeletonHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Phase 0 skeleton',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Owned by Sapati. Tap a screen to open its placeholder.'),
          const SizedBox(height: 16),
          for (final link in _links)
            Card(
              child: ListTile(
                title: Text(link.label),
                subtitle: Text('Owner: ${link.owner}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(link.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _Link {
  const _Link(this.label, this.path, this.owner);
  final String label;
  final String path;
  final String owner;
}

const List<_Link> _links = [
  _Link('Sign in', '/auth', 'Mohan'),
  _Link('Profile and ID', '/profile', 'Mohan'),
  _Link('Explore', '/explore', 'Smaran'),
  _Link('Item details', '/item-details', 'Smaran'),
  _Link('My bookings', '/bookings', 'Smaran'),
  _Link('Notifications', '/notifications', 'Smaran'),
  _Link('Reviews', '/reviews', 'Smaran'),
  _Link('My listings', '/listings', 'Srijan'),
  _Link('Requests inbox', '/inbox', 'Srijan'),
  _Link('Handover and return', '/handover', 'Srijan'),
  _Link('Earnings', '/earnings', 'Srijan'),
];
