import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Swipeable photos (1 to 5) with page dots. Shows a placeholder when the item
/// has no photo or a photo cannot load.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({required this.photoUrls, super.key});

  final List<String> photoUrls;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) return const _Placeholder();
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: widget.photoUrls.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => Image.network(
              widget.photoUrls[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _Placeholder(),
              errorBuilder: (context, error, stack) => const _Placeholder(),
            ),
          ),
          if (widget.photoUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.photoUrls.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? BrandColors.hotPink
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(
        color: BrandColors.border,
        child: Center(
          child: Icon(Icons.image_outlined, color: BrandColors.textMuted),
        ),
      ),
    );
  }
}
