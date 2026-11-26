import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../application/explore_controller.dart';
import 'filter_sheet.dart';

/// Borrower home: search, category chips, filters and the paginated list.
/// Owner: Smaran.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) {
      ref.read(exploreControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters(ItemQuery query) async {
    final choice = await showFilterSheet(context, query);
    if (choice == null || !mounted) return;
    ref.read(exploreControllerProvider.notifier).applyFilters(
          area: choice.area,
          minPrice: choice.minPrice,
          maxPrice: choice.maxPrice,
          sort: choice.sort,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: controller.setSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search cameras, tents, guitars...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: state.query.activeFilterCount > 0,
                  label: Text('${state.query.activeFilterCount}'),
                  child: IconButton.outlined(
                    tooltip: 'Filters',
                    icon: const Icon(Icons.tune),
                    onPressed: () => _openFilters(state.query),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: state.query.category == null,
                    onSelected: (_) => controller.setCategory(null),
                  ),
                ),
                for (final category in kItemCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: state.query.category == category,
                      onSelected: (_) => controller.setCategory(category),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody(state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(ExploreState state, ExploreController controller) {
    if (state.status == ExploreStatus.loading && state.items.isEmpty) {
      return const LoadingView(message: 'Loading items');
    }
    if (state.status == ExploreStatus.error && state.items.isEmpty) {
      return ErrorState(
        message: state.errorMessage ?? 'Something went wrong.',
        onRetry: controller.retry,
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        title: 'No items found',
        message: 'Try a different search or clear the filters.',
        icon: Icons.search_off,
        action: SecondaryButton(
          label: 'Clear filters',
          onPressed: controller.clearAll,
        ),
      );
    }

    final showFooter = state.status == ExploreStatus.loadingMore ||
        state.status == ExploreStatus.error;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.items.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return _Footer(state: state, onRetry: controller.loadMore);
          }
          final item = state.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ItemCard(
              title: item.title,
              pricePerDay: item.dailyPrice,
              area: item.pickupArea,
              imageUrl: item.coverPhoto,
              onTap: () => context.push('/item-details/${item.id}'),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom of the list: a spinner while loading more, or a retry after an error.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final ExploreState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.status == ExploreStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SecondaryButton(
          label: 'Could not load more. Tap to retry',
          onPressed: onRetry,
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
