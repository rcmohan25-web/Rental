import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Smaran).
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: const PlaceholderView(
        title: 'Reviews',
        owner: 'Smaran',
        description: 'Ratings and reviews after completion (Phase 4, first to cut).',
      ),
    );
  }
}
