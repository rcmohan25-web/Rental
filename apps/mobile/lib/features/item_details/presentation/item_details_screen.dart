import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Smaran).
class ItemDetailsScreen extends StatelessWidget {
  const ItemDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: const PlaceholderView(
        title: 'Item details',
        owner: 'Smaran',
        description:
            'Photo carousel, condition, daily price, deposit shown separately, date picker with blocked dates, cost breakdown.',
      ),
    );
  }
}
