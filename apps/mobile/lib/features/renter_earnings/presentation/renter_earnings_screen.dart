import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Srijan).
class RenterEarningsScreen extends StatelessWidget {
  const RenterEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: const PlaceholderView(
        title: 'Earnings',
        owner: 'Srijan',
        description: 'Earnings screen: on hold, due, paid.',
      ),
    );
  }
}
