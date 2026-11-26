import 'package:equatable/equatable.dart';

import '../models/models.dart';

/// How the Explore list is ordered.
enum ItemSort { newest, priceLowToHigh, priceHighToLow }

/// The filters of the Explore screen. All fields are optional.
class ItemQuery extends Equatable {
  const ItemQuery({
    this.search,
    this.area,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.sort = ItemSort.newest,
  });

  /// Matches the item title (case-insensitive "contains").
  final String? search;
  final Area? area;
  final String? category;

  /// Daily price range in NPR, both ends inclusive.
  final int? minPrice;
  final int? maxPrice;
  final ItemSort sort;

  /// How many filters (not counting search and category) are switched on.
  int get activeFilterCount =>
      (area != null ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (sort != ItemSort.newest ? 1 : 0);

  ItemQuery copyWith({
    String? search,
    Area? area,
    String? category,
    int? minPrice,
    int? maxPrice,
    ItemSort? sort,
    bool clearSearch = false,
    bool clearArea = false,
    bool clearCategory = false,
    bool clearPrice = false,
  }) =>
      ItemQuery(
        search: clearSearch ? null : (search ?? this.search),
        area: clearArea ? null : (area ?? this.area),
        category: clearCategory ? null : (category ?? this.category),
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        sort: sort ?? this.sort,
      );

  @override
  List<Object?> get props => [search, area, category, minPrice, maxPrice, sort];
}

/// Keyset pagination: "give me the items after this one". Stays fast at any
/// size, unlike OFFSET. The real repository uses the field matching the sort.
class ItemCursor extends Equatable {
  const ItemCursor({
    required this.id,
    required this.createdAt,
    required this.dailyPrice,
  });

  final String id;
  final DateTime createdAt;
  final int dailyPrice;

  @override
  List<Object?> get props => [id, createdAt, dailyPrice];
}

/// One page of Explore results.
class ItemPage extends Equatable {
  const ItemPage({required this.items, this.nextCursor});

  final List<Item> items;

  /// Null when there are no more pages.
  final ItemCursor? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}

/// Read access to listings. Renter-side writes (add, edit, pause) belong to
/// Srijan's `renter_listings` feature and will extend a separate interface.
abstract class ItemRepository {
  /// Active, not removed items matching [query]. 12 per page by default.
  Future<ItemPage> listItems({
    ItemQuery query = const ItemQuery(),
    ItemCursor? after,
    int pageSize = 12,
  });

  /// One item with the Renter's first name. Throws AppException with code
  /// ITEM_UNAVAILABLE when it is missing, paused or removed.
  Future<Item> getItem(String id);
}
