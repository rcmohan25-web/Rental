import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../../shared/id_gate.dart';
import '../application/listing_error_messages.dart';
import '../application/listing_providers.dart';

/// Listings tab: the Renter's items with pause, edit and delete. Owner: Srijan.
class RenterListingsScreen extends ConsumerWidget {
  const RenterListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myItemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings'),
        actions: [
          IconButton(
            tooltip: 'Requests inbox',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push('/inbox'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BrandColors.hotPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add listing',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        onPressed: () async {
          // The ID gate: an ID must be submitted before the first listing.
          if (!await ensureIdSubmitted(context, ref)) return;
          if (context.mounted) await context.push('/listings/new');
        },
      ),
      body: items.when(
        loading: () => const LoadingView(message: 'Loading your listings'),
        error: (e, _) => ErrorState(
          message: friendlyListingError(e),
          onRetry: () => ref.invalidate(myItemsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'No listings yet',
                message: 'Lend an item you do not use. Tap Add listing.',
                icon: Icons.inventory_2_outlined,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myItemsProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ListingCard(item: list[i]),
                ),
              ),
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.item});

  final Item item;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(myItemsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyListingError(e))));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text(
          'Pending requests are declined. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(listingRepositoryProvider).deleteListing(item.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, tone) = switch (item.status) {
      ItemStatus.active => ('Active', StatusTone.success),
      ItemStatus.paused => ('Paused', StatusTone.warning),
      ItemStatus.draft => ('Draft', StatusTone.neutral),
    };
    final repository = ref.read(listingRepositoryProvider);
    return Card(
      child: InkWell(
        onTap: () => context.push('/listings/${item.id}/edit'),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.coverPhoto == null
                      ? const ColoredBox(
                          color: BrandColors.border,
                          child: Icon(Icons.image_outlined),
                        )
                      : Image.network(
                          item.coverPhoto!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: BrandColors.border,
                            child: Icon(Icons.image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('${Formatters.npr(item.dailyPrice)} / day'),
                    const SizedBox(height: 4),
                    StatusChip(label: label, tone: tone),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (choice) {
                  switch (choice) {
                    case 'edit':
                      context.push('/listings/${item.id}/edit');
                    case 'pause':
                      _run(
                        context,
                        ref,
                        () => repository.setStatus(item.id, ItemStatus.paused),
                      );
                    case 'publish':
                      _run(context, ref, () async {
                        if (!await ensureIdSubmitted(context, ref)) return;
                        await repository.setStatus(item.id, ItemStatus.active);
                      });
                    case 'delete':
                      _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (item.status == ItemStatus.active)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  if (item.status != ItemStatus.active)
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
