import 'package:equatable/equatable.dart';

import '../models/models.dart';
import 'image_upload.dart';

/// One photo of a listing: either already stored (path + public URL) or a new
/// upload. The first photo is the cover.
class ListingPhoto extends Equatable {
  const ListingPhoto.stored({
    required String this.path,
    required String this.url,
  }) : upload = null;
  const ListingPhoto.upload(ImageUpload this.upload)
      : path = null,
        url = null;

  /// Storage path in the `item-photos` bucket (stored photos only).
  final String? path;
  final String? url;
  final ImageUpload? upload;

  bool get isNew => upload != null;

  @override
  List<Object?> get props => [path, url, upload];
}

/// What the Renter fills in. Money is whole NPR.
class ListingInput extends Equatable {
  const ListingInput({
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.declaredValue,
    required this.dailyPrice,
    required this.pickupArea,
    required this.exactAddress,
    required this.photos,
    this.rules,
    this.pickupInstructions,
    this.publish = true,
  });

  final String title;
  final String description;
  final String category;
  final String condition;
  final int declaredValue;
  final int dailyPrice;

  /// Public text such as "Jawalakhel Chowk, Lalitpur". The exact address below
  /// stays private until payment is verified.
  final String pickupArea;
  final String exactAddress;
  final String? pickupInstructions;
  final String? rules;

  /// 1 to 5 photos for a published listing.
  final List<ListingPhoto> photos;

  /// True saves the listing as active, false as a draft.
  final bool publish;

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        condition,
        declaredValue,
        dailyPrice,
        pickupArea,
        exactAddress,
        pickupInstructions,
        rules,
        photos,
        publish,
      ];
}

/// A listing as the owner sees it (with the private address).
class MyListing extends Equatable {
  const MyListing({
    required this.item,
    required this.photos,
    required this.exactAddress,
    this.pickupInstructions,
  });

  final Item item;
  final List<ListingPhoto> photos;
  final String exactAddress;
  final String? pickupInstructions;

  @override
  List<Object?> get props => [item, photos, exactAddress, pickupInstructions];
}

/// Renter-side listing writes (add, edit, pause, delete). Failures throw
/// AppException with contract codes (KYC_REQUIRED, INVALID_VALUE,
/// SETTING_UNAVAILABLE, EVIDENCE_MISSING, ACTIVE_BOOKINGS_EXIST ...).
abstract class ListingRepository {
  /// The signed-in owner's items (draft, active, paused), newest first.
  Future<List<Item>> listMyItems();

  Future<MyListing> getMyListing(String itemId);

  /// Uploads new photos, saves the item as a draft, saves the private address,
  /// then publishes when [ListingInput.publish] is true. A failure after the
  /// first step leaves a draft, never a public listing without an address.
  Future<Item> createListing(ListingInput input);

  Future<Item> updateListing(String itemId, ListingInput input);

  /// Pause (ItemStatus.paused) or republish (ItemStatus.active).
  Future<Item> setStatus(String itemId, ItemStatus status);

  /// RPC `delete_item` (soft delete).
  Future<void> deleteListing(String itemId);
}
