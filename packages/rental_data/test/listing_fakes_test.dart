import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart' show AppException;
import 'package:rental_data/rental_data.dart';

Future<String?> errorCode(Future<Object?> Function() action) async {
  try {
    await action();
    return null;
  } on AppException catch (e) {
    return e.code;
  }
}

ListingPhoto _photo() =>
    ListingPhoto.upload(ImageUpload(bytes: Uint8List.fromList([1, 2, 3])));

ListingInput _input({
  List<ListingPhoto>? photos,
  bool publish = true,
  int declared = 160000,
  String title = 'Sony camera',
}) => ListingInput(
  title: title,
  description: 'Full frame',
  category: 'Cameras',
  condition: 'Good',
  declaredValue: declared,
  dailyPrice: 3500,
  pickupArea: 'Jawalakhel Chowk, Lalitpur',
  exactAddress: 'House 7, Jawalakhel',
  photos: photos ?? [_photo()],
  publish: publish,
);

void main() {
  test('create and publish shows the item as active with its photo', () async {
    final repo = FakeListingRepository();
    final item = await repo.createListing(_input());
    expect(item.status, ItemStatus.active);
    expect(item.photoUrls.length, 1);
    expect(item.area, Area.lalitpur);
    expect((await repo.listMyItems()).single.id, item.id);
    final mine = await repo.getMyListing(item.id);
    expect(mine.exactAddress, 'House 7, Jawalakhel');
    expect(mine.photos.single.isNew, isFalse);
  });

  test('a draft needs fewer fields than a published listing', () async {
    final repo = FakeListingRepository();
    final draft = await repo.createListing(_input(photos: [], publish: false));
    expect(draft.status, ItemStatus.draft);
    expect(
      await errorCode(() => repo.createListing(_input(photos: []))),
      'INVALID_VALUE',
    );
  });

  test('publishing below the minimum declared value is refused', () async {
    final repo = FakeListingRepository();
    expect(
      await errorCode(() => repo.createListing(_input(declared: 500))),
      'INVALID_VALUE',
    );
  });

  test(
    'publishing without an ID gives KYC_REQUIRED, drafts still work',
    () async {
      final repo = FakeListingRepository(kycOk: false);
      expect(
        await errorCode(() => repo.createListing(_input())),
        'KYC_REQUIRED',
      );
      expect(
        (await repo.createListing(_input(publish: false))).status,
        ItemStatus.draft,
      );
    },
  );

  test('update keeps stored photos, pause and delete work', () async {
    final repo = FakeListingRepository();
    final item = await repo.createListing(_input());
    final stored = (await repo.getMyListing(item.id)).photos;
    final updated = await repo.updateListing(
      item.id,
      _input(photos: [...stored, _photo()], title: 'Sony A7 III'),
    );
    expect(updated.title, 'Sony A7 III');
    expect(updated.photoUrls.length, 2);

    expect(
      (await repo.setStatus(item.id, ItemStatus.paused)).status,
      ItemStatus.paused,
    );
    await repo.deleteListing(item.id);
    expect(await repo.listMyItems(), isEmpty);
  });
}
