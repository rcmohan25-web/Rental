import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Smaran).
class BorrowerBookingsScreen extends StatelessWidget {
  const BorrowerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: const PlaceholderView(
        title: 'My bookings',
        owner: 'Smaran',
        description:
            'Request form, status timeline, next-step banner, borrower terms tick before payment, payment proof upload, receipt confirmation, refund status.',
      ),
    );
  }
}
