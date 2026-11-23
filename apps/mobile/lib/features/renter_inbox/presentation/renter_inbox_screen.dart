import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Srijan).
class RenterInboxScreen extends StatelessWidget {
  const RenterInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Requests inbox')),
      body: const PlaceholderView(
        title: 'Requests inbox',
        owner: 'Srijan',
        description:
            'Incoming requests, accept or decline, renter terms tick right after Accept.',
      ),
    );
  }
}
