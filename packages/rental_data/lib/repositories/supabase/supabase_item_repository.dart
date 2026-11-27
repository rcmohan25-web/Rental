import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../item_repository.dart';
import 'supabase_helpers.dart';

/// Public listings from the `public_items` view (active, not deleted, owner
/// active with an ID submitted; Renter first name; no exact address).
class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository(this._client);

  final SupabaseClient _client;

  /// Characters that would change the meaning of a PostgREST pattern.
  static String _cleanPattern(String text) =>
      text.replaceAll(RegExp(r'[%_,()*\\]'), ' ').trim();

  @override
  Future<ItemPage> listItems({
    ItemQuery query = const ItemQuery(),
    ItemCursor? after,
    int pageSize = 12,
  }) =>
      guarded(() async {
        var request = _client.from('public_items').select();

        final search = _cleanPattern(query.search ?? '');
        if (search.isNotEmpty) request = request.ilike('title', '%$search%');
        if (query.category != null) {
          request = request.eq('category', query.category!);
        }
        if (query.area != null) {
          request = request.ilike('pickup_area', '%${query.area!.label}%');
        }
        if (query.minPrice != null) {
          request = request.gte('daily_rate', query.minPrice!);
        }
        if (query.maxPrice != null) {
          request = request.lte('daily_rate', query.maxPrice!);
        }

        // Keyset pagination: continue after the last row of the previous page.
        if (after != null) {
          final created = after.createdAt.toUtc().toIso8601String();
          request = switch (query.sort) {
            ItemSort.newest => request.or(
                'created_at.lt.$created,'
                'and(created_at.eq.$created,id.lt.${after.id})',
              ),
            ItemSort.priceLowToHigh => request.or(
                'daily_rate.gt.${after.dailyPrice},'
                'and(daily_rate.eq.${after.dailyPrice},id.gt.${after.id})',
              ),
            ItemSort.priceHighToLow => request.or(
                'daily_rate.lt.${after.dailyPrice},'
                'and(daily_rate.eq.${after.dailyPrice},id.lt.${after.id})',
              ),
          };
        }

        final ordered = switch (query.sort) {
          ItemSort.newest => request
              .order('created_at', ascending: false)
              .order('id', ascending: false),
          ItemSort.priceLowToHigh => request
              .order('daily_rate', ascending: true)
              .order('id', ascending: true),
          ItemSort.priceHighToLow => request
              .order('daily_rate', ascending: false)
              .order('id', ascending: false),
        };

        // One extra row tells whether another page exists.
        final rows = await ordered.limit(pageSize + 1);
        final items = [for (final row in rows) _toItem(asRow(row))];
        final hasMore = items.length > pageSize;
        final page = hasMore ? items.sublist(0, pageSize) : items;
        return ItemPage(
          items: page,
          nextCursor: hasMore
              ? ItemCursor(
                  id: page.last.id,
                  createdAt: page.last.createdAt,
                  dailyPrice: page.last.dailyPrice,
                )
              : null,
        );
      });

  @override
  Future<Item> getItem(String id) => guarded(() async {
        final row = await _client
            .from('public_items')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          throw const AppException('Item not available',
              code: 'ITEM_UNAVAILABLE');
        }
        return _toItem(asRow(row));
      });

  Item _toItem(Map<String, dynamic> row) {
    final paths = List<String>.from(row['photo_paths'] as List? ?? const []);
    final bucket = _client.storage.from('item-photos');
    return Item.fromJson({
      ...row,
      'photo_urls': [for (final path in paths) bucket.getPublicUrl(path)],
    });
  }
}
