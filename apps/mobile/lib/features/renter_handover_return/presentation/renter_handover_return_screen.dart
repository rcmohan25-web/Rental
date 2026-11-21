import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Srijan).
class RenterHandoverReturnScreen extends StatelessWidget {
  const RenterHandoverReturnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handover and return')),
      body: const PlaceholderView(
        title: 'Handover and return',
        owner: 'Srijan',
        description:
            'Evidence photos, checklist, handover code entry, borrower ID and face photo, return and damage report.',
      ),
    );
  }
}
