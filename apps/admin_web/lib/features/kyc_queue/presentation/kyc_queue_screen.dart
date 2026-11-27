import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../shell/application/admin_providers.dart';
import '../application/kyc_queue_providers.dart';

/// ID verification queue: compare the ID photo with the face photo, then
/// approve or reject with a reason. "Verified" means checked by an admin.
class KycQueueScreen extends ConsumerWidget {
  const KycQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingKycProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID verification queue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(pendingKycProvider),
              ),
            ],
          ),
          const Text(
            '${HonestyTexts.identityManual} Photos are private and open '
            'through short-lived links.',
            style: TextStyle(color: BrandColors.textMuted),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pending.when(
              loading: () => const LoadingView(message: 'Loading queue'),
              error: (e, _) =>
                  ErrorState(onRetry: () => ref.invalidate(pendingKycProvider)),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      title: 'No IDs waiting',
                      message: 'New submissions appear here.',
                      icon: Icons.badge_outlined,
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _PendingCard(item: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.item});

  final PendingKyc item;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adminKycRepositoryProvider)
          .review(userId: widget.item.userId, approve: approve, reason: reason);
      ref.invalidate(pendingKycProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'ID marked as checked.' : 'ID rejected with a reason.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException && e.code == 'INVALID_STATE'
                ? 'Someone already reviewed this ID. Reload the queue.'
                : 'Could not save. Please try again.',
          ),
        ),
      );
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Why is this ID rejected?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'The user sees this and can submit again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Submitted ${Formatters.dateTime(item.submittedAt.toLocal())}',
              style: const TextStyle(color: BrandColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Photo(label: 'ID', url: item.idPhotoUrl, width: 320),
                _Photo(label: 'Face', url: item.facePhotoUrl, width: 220),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Reject',
                    onPressed: _busy ? null : () => _decide(approve: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Mark as checked',
                    loading: _busy,
                    onPressed: () => _decide(approve: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, required this.url, required this.width});

  final String label;
  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(48),
                child: Text('Photo link expired. Reload the queue.'),
              ),
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: width,
              height: width * 0.65,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: BrandColors.border,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
