import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

import '../../explore/application/catalog_providers.dart';
import 'booking_error_messages.dart';

/// Everything the Item details screen needs, loaded together.
class ItemDetailsData {
  const ItemDetailsData._({
    this.item,
    this.blockedDates = const [],
    this.settings,
    this.errorMessage,
  });

  const ItemDetailsData.loaded({
    required Item item,
    required List<DateRange> blockedDates,
    required AppSettings settings,
  }) : this._(item: item, blockedDates: blockedDates, settings: settings);

  const ItemDetailsData.failed(String message) : this._(errorMessage: message);

  final Item? item;
  final List<DateRange> blockedDates;
  final AppSettings? settings;
  final String? errorMessage;
}

/// Never throws: a failure becomes `ItemDetailsData.failed`, so the screen can
/// show a clear message (and Riverpod does not retry a permanent error).
final itemDetailsProvider = FutureProvider.autoDispose
    .family<ItemDetailsData, String>((ref, itemId) async {
  try {
    final item = await ref.read(itemRepositoryProvider).getItem(itemId);
    final blocked =
        await ref.read(bookingRepositoryProvider).blockedDates(itemId);
    final settings = await ref.read(settingsRepositoryProvider).getSettings();
    return ItemDetailsData.loaded(
      item: item,
      blockedDates: blocked,
      settings: settings,
    );
  } catch (e) {
    return ItemDetailsData.failed(friendlyBookingError(e));
  }
});
