import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Srijan).
class RenterListingsScreen extends StatelessWidget {
  const RenterListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: const PlaceholderView(
        title: 'My listings',
        owner: 'Srijan',
        description:
            'Add, edit, pause and delete listings (1 to 5 photos, declared value, rules, pickup area).',
      ),
    );
  }
}
