import 'package:rental_core/rental_core.dart' show AppException;

import '../../models/models.dart';
import '../listing_repository.dart';
import 'fake_data.dart';

/// In-memory listings of one Renter. Applies the same rules the database
/// trigger applies when a listing is published.
class FakeListingRepository implements ListingRepository {
  FakeListingRepository({
    this.ownerId = FakeData.lenderAayushId,
    this.ownerFirstName = 'Aayush',
    this.kycOk = true,
    this.minDeclaredValue = 2000,
    this.latency = Duration.zero,
  });

  final String ownerId;
  final String ownerFirstName;

  /// False makes publishing fail with KYC_REQUIRED.
  final bool kycOk;
  final int minDeclaredValue;
  final Duration latency;

  final List<MyListing> _listings = [];
  int _counter = 0;

  void _validate(ListingInput input, {required bool publishing}) {
    if (input.title.trim().isEmpty || input.dailyPrice < 1) {
      throw const AppException('Check the form.', code: 'INVALID_VALUE');
    }
    if (!publishing) return;
    if (!kycOk) {
      throw const AppException('ID needed.', code: 'KYC_REQUIRED');
    }
    if (input.declaredValue < minDeclaredValue ||
        input.category.trim().isEmpty ||
        input.condition.trim().isEmpty ||
        input.photos.isEmpty ||
        input.photos.length > 5) {
      throw const AppException('Check the form.', code: 'INVALID_VALUE');
    }
  }

  List<ListingPhoto> _stored(List<ListingPhoto> photos, String id) => [
        for (var i = 0; i < photos.length; i++)
          photos[i].isNew
              ? ListingPhoto.stored(
                  path: '$ownerId/$id-$i.jpg',
                  url: 'https://picsum.photos/seed/$id-$i/800/600',
                )
              : photos[i],
      ];

  Item _item(
    String id,
    ListingInput input,
    ItemStatus status,
    List<ListingPhoto> photos,
    DateTime createdAt,
  ) =>
      Item(
        id: id,
        lenderId: ownerId,
        lenderFirstName: ownerFirstName,
        category: input.category,
        title: input.title.trim(),
        description: input.description.trim(),
        condition: input.condition,
        declaredValue: input.declaredValue,
        dailyPrice: input.dailyPrice,
        pickupArea: input.pickupArea,
        photoUrls: [for (final p in photos) p.url!],
        rules: input.rules,
        status: status,
        createdAt: createdAt,
      );

  @override
  Future<List<Item>> listMyItems() async {
    await Future<void>.delayed(latency);
    final items = [for (final l in _listings) l.item]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<MyListing> getMyListing(String itemId) async {
    await Future<void>.delayed(latency);
    return _listings.firstWhere(
      (l) => l.item.id == itemId,
      orElse: () => throw const AppException('Not found.', code: 'NOT_ALLOWED'),
    );
  }

  @override
  Future<Item> createListing(ListingInput input) async {
    await Future<void>.delayed(latency);
    _validate(input, publishing: input.publish);
    final id = 'fake-listing-${++_counter}';
    final photos = _stored(input.photos, id);
    final item = _item(
      id,
      input,
      input.publish ? ItemStatus.active : ItemStatus.draft,
      photos,
      DateTime.now().toUtc(),
    );
    _listings.add(
      MyListing(
        item: item,
        photos: photos,
        exactAddress: input.exactAddress,
        pickupInstructions: input.pickupInstructions,
      ),
    );
    return item;
  }

  @override
  Future<Item> updateListing(String itemId, ListingInput input) async {
    await Future<void>.delayed(latency);
    final index = _listings.indexWhere((l) => l.item.id == itemId);
    if (index == -1) {
      throw const AppException('Not found.', code: 'NOT_ALLOWED');
    }
    _validate(input, publishing: input.publish);
    final photos = _stored(input.photos, itemId);
    final item = _item(
      itemId,
      input,
      input.publish ? ItemStatus.active : _listings[index].item.status,
      photos,
      _listings[index].item.createdAt,
    );
    _listings[index] = MyListing(
      item: item,
      photos: photos,
      exactAddress: input.exactAddress,
      pickupInstructions: input.pickupInstructions,
    );
    return item;
  }

  @override
  Future<Item> setStatus(String itemId, ItemStatus status) async {
    await Future<void>.delayed(latency);
    final index = _listings.indexWhere((l) => l.item.id == itemId);
    if (index == -1) {
      throw const AppException('Not found.', code: 'NOT_ALLOWED');
    }
    if (status == ItemStatus.active && !kycOk) {
      throw const AppException('ID needed.', code: 'KYC_REQUIRED');
    }
    final old = _listings[index];
    final item = old.item.copyWith(status: status);
    _listings[index] = MyListing(
      item: item,
      photos: old.photos,
      exactAddress: old.exactAddress,
      pickupInstructions: old.pickupInstructions,
    );
    return item;
  }

  @override
  Future<void> deleteListing(String itemId) async {
    await Future<void>.delayed(latency);
    _listings.removeWhere((l) => l.item.id == itemId);
  }
}
