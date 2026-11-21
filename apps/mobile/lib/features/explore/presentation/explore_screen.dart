import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Smaran).
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: const PlaceholderView(
        title: 'Explore',
        owner: 'Smaran',
        description:
            'Item list, category chips, search, price and area filters, sort.',
      ),
    );
  }
}
