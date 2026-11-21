import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../formatters/formatters.dart';
import '../theme/brand_colors.dart';

/// Listing card used in explore and the renter's listings.
class ItemCard extends StatelessWidget {
  const ItemCard({
    required this.title,
    required this.pricePerDay,
    required this.area,
    this.imageUrl,
    this.onTap,
    super.key,
  });

  final String title;
  final num pricePerDay;
  final String area;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: imageUrl == null
                  ? const _ImagePlaceholder()
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _ImagePlaceholder(),
                      errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.npr(pricePerDay)} / day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: BrandColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        area,
                        style: const TextStyle(
                          fontSize: 13,
                          color: BrandColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: BrandColors.border,
      child: Center(
        child: Icon(Icons.image_outlined, color: BrandColors.textMuted),
      ),
    );
  }
}
