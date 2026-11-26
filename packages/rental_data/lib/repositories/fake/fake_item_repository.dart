import 'package:rental_core/rental_core.dart' show AppException;

import '../../models/models.dart';
import '../item_repository.dart';
import 'fake_data.dart';

/// In-memory listings for UI work and tests. Filters, sorting and keyset
/// pagination behave like the real repository will.
class FakeItemRepository implements ItemRepository {
  FakeItemRepository({List<Item>? items, this.latency = Duration.zero})
      : _items = List<Item>.of(items ?? FakeData.items);

  final List<Item> _items;

  /// Simulated network delay. Keep it zero in tests.
  final Duration latency;

  @override
  Future<ItemPage> listItems({
    ItemQuery query = const ItemQuery(),
    ItemCursor? after,
    int pageSize = 12,
  }) async {
    await Future<void>.delayed(latency);

    final filtered = _items.where((item) => _matches(item, query)).toList()
      ..sort((a, b) => _compare(a, b, query.sort));

    var start = 0;
    if (after != null) {
      final index = filtered.indexWhere((item) => item.id == after.id);
      start = index == -1 ? 0 : index + 1;
    }
    final end =
        start + pageSize > filtered.length ? filtered.length : start + pageSize;
    final page = filtered.sublist(start, end);
    final hasMore = end < filtered.length;

    return ItemPage(
      items: page,
      nextCursor: hasMore && page.isNotEmpty
          ? ItemCursor(
              id: page.last.id,
              createdAt: page.last.createdAt,
              dailyPrice: page.last.dailyPrice,
            )
          : null,
    );
  }

  @override
  Future<Item> getItem(String id) async {
    await Future<void>.delayed(latency);
    for (final item in _items) {
      if (item.id == id && item.isActive) return item;
    }
    throw const AppException('Item not available', code: 'ITEM_UNAVAILABLE');
  }

  bool _matches(Item item, ItemQuery q) {
    if (!item.isActive) return false;
    if (q.area != null && item.area != q.area) return false;
    if (q.category != null && item.category != q.category) return false;
    if (q.minPrice != null && item.dailyPrice < q.minPrice!) return false;
    if (q.maxPrice != null && item.dailyPrice > q.maxPrice!) return false;
    final text = q.search?.trim().toLowerCase();
    if (text != null && text.isNotEmpty) {
      if (!item.title.toLowerCase().contains(text)) return false;
    }
    return true;
  }

  /// The id is the tie-breaker so the order is always stable.
  int _compare(Item a, Item b, ItemSort sort) {
    final byKey = switch (sort) {
      ItemSort.newest => b.createdAt.compareTo(a.createdAt),
      ItemSort.priceLowToHigh => a.dailyPrice.compareTo(b.dailyPrice),
      ItemSort.priceHighToLow => b.dailyPrice.compareTo(a.dailyPrice),
    };
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  }
}
