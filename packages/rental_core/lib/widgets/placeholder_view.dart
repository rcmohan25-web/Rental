import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// Temporary content for a screen that is not built yet.
/// Each feature owner replaces it with the real screen.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    required this.title,
    required this.owner,
    this.description,
    super.key,
  });

  final String title;
  final String owner;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48, color: BrandColors.navy),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Placeholder. Owner: $owner',
                style: const TextStyle(color: BrandColors.textMuted),
              ),
              if (description != null) ...[
                const SizedBox(height: 12),
                Text(description!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
