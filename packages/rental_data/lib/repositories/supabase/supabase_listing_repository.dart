import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../listing_repository.dart';
import 'supabase_helpers.dart';

/// Renter-side listing writes. Direct table writes are allowed by the column
/// grants and RLS from the Phase 0 migrations; the publish checks (ID, minimum
/// declared value, photos) run in the `validate_listing` trigger.
class SupabaseListingRepository implements ListingRepository {
  SupabaseListingRepository(this._client);

  final SupabaseClient _client;

  static const String _bucketName = 'item-photos';

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException(
        'Please sign in to continue.',
        code: 'NOT_AUTHENTICATED',
      );
    }
    return id;
  }

  Item _toItem(Map<String, dynamic> row) {
    final paths = List<String>.from(row['photo_paths'] as List? ?? const []);
    final bucket = _client.storage.from(_bucketName);
    return Item.fromJson({
      ...row,
      'photo_urls': [for (final path in paths) bucket.getPublicUrl(path)],
    });
  }

  /// Uploads the new photos (in order) and returns the final path list.
  Future<List<String>> _storePhotos(List<ListingPhoto> photos) async {
    final userId = _userId();
    final bucket = _client.storage.from(_bucketName);
    final paths = <String>[];
    for (final photo in photos) {
      final upload = photo.upload;
      if (upload == null) {
        paths.add(photo.path!);
        continue;
      }
      final path = '$userId/${randomId()}.${extensionFor(upload)}';
      await bucket.uploadBinary(
        path,
        upload.bytes,
        fileOptions: FileOptions(contentType: upload.contentType),
      );
      paths.add(path);
    }
    return paths;
  }

  Map<String, dynamic> _fields(ListingInput input, List<String> paths) => {
    'title': input.title.trim(),
    'description': input.description.trim(),
    'category': input.category,
    'condition': input.condition,
    'declared_value': input.declaredValue,
    'daily_rate': input.dailyPrice,
    'pickup_area': input.pickupArea.trim(),
    'rules': (input.rules == null || input.rules!.trim().isEmpty)
        ? null
        : input.rules!.trim(),
    'photo_paths': paths,
  };

  Future<void> _savePickup(String itemId, ListingInput input) async {
    final instructions = (input.pickupInstructions ?? '').trim();
    final values = {
      'exact_address': input.exactAddress.trim(),
      'instructions': instructions.isEmpty ? null : instructions,
    };
    final updated = await _client
        .from('item_pickup_details')
        .update(values)
        .eq('item_id', itemId)
        .select();
    if (updated.isEmpty) {
      await _client.from('item_pickup_details').insert({
        'item_id': itemId,
        ...values,
      });
    }
  }

  @override
  Future<List<Item>> listMyItems() => guarded(() async {
    final rows = await _client
        .from('items')
        .select()
        .eq('lender_id', _userId())
        .order('created_at', ascending: false);
    return [for (final row in rows) _toItem(asRow(row))];
  });

  @override
  Future<MyListing> getMyListing(String itemId) => guarded(() async {
    final row = await _client
        .from('items')
        .select()
        .eq('id', itemId)
        .eq('lender_id', _userId())
        .maybeSingle();
    if (row == null) {
      throw const AppException('Not found.', code: 'NOT_ALLOWED');
    }
    final map = asRow(row);
    final pickup = await _client
        .from('item_pickup_details')
        .select()
        .eq('item_id', itemId)
        .maybeSingle();
    final bucket = _client.storage.from(_bucketName);
    return MyListing(
      item: _toItem(map),
      photos: [
        for (final path in List<String>.from(
          map['photo_paths'] as List? ?? const [],
        ))
          ListingPhoto.stored(path: path, url: bucket.getPublicUrl(path)),
      ],
      exactAddress: (pickup?['exact_address'] as String?) ?? '',
      pickupInstructions: pickup?['instructions'] as String?,
    );
  });

  @override
  Future<Item> createListing(ListingInput input) => guarded(() async {
    final userId = _userId();
    final paths = await _storePhotos(input.photos);
    // Draft first: if a later step fails, nothing public exists.
    final created = asRow(
      await _client
          .from('items')
          .insert({
            'lender_id': userId,
            'status': 'draft',
            ..._fields(input, paths),
          })
          .select()
          .single(),
    );
    final itemId = created['id'] as String;
    await _savePickup(itemId, input);
    if (!input.publish) return _toItem(created);
    final published = asRow(
      await _client
          .from('items')
          .update({'status': 'active'})
          .eq('id', itemId)
          .select()
          .single(),
    );
    return _toItem(published);
  });

  @override
  Future<Item> updateListing(String itemId, ListingInput input) =>
      guarded(() async {
        final before = asRow(
          await _client
              .from('items')
              .select('status, photo_paths')
              .eq('id', itemId)
              .single(),
        );
        final oldPaths = List<String>.from(before['photo_paths'] as List);
        final paths = await _storePhotos(input.photos);
        var row = asRow(
          await _client
              .from('items')
              .update(_fields(input, paths))
              .eq('id', itemId)
              .select()
              .single(),
        );
        await _savePickup(itemId, input);
        if (input.publish && before['status'] != 'active') {
          row = asRow(
            await _client
                .from('items')
                .update({'status': 'active'})
                .eq('id', itemId)
                .select()
                .single(),
          );
        }
        // Remove photos the owner took out. Best effort: a referenced photo
        // cannot be deleted by the storage policy, and that is fine.
        final removed = oldPaths.where((p) => !paths.contains(p)).toList();
        if (removed.isNotEmpty) {
          try {
            await _client.storage.from(_bucketName).remove(removed);
          } catch (_) {}
        }
        return _toItem(row);
      });

  @override
  Future<Item> setStatus(String itemId, ItemStatus status) => guarded(() async {
    final row = asRow(
      await _client
          .from('items')
          .update({'status': status.wire})
          .eq('id', itemId)
          .select()
          .single(),
    );
    return _toItem(row);
  });

  @override
  Future<void> deleteListing(String itemId) => guarded(() async {
    await _client.rpc('delete_item', params: {'p_item_id': itemId});
  });
}
