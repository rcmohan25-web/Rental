import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Smaran).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const PlaceholderView(
        title: 'Notifications',
        owner: 'Smaran',
        description: 'Realtime in-app notification centre.',
      ),
    );
  }
}
