import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental/features/explore/application/catalog_providers.dart';
import 'package:rental/features/item_details/presentation/item_details_screen.dart';
import 'package:rental_data/rental_data.dart';

Item _noPhotos(Item item) => Item(
      id: item.id,
      lenderId: item.lenderId,
      lenderFirstName: item.lenderFirstName,
      category: item.category,
      title: item.title,
      description: item.description,
      condition: item.condition,
      declaredValue: item.declaredValue,
      dailyPrice: item.dailyPrice,
      pickupArea: item.pickupArea,
      photoUrls: const [],
      status: ItemStatus.active,
      createdAt: item.createdAt,
    );

void main() {
  testWidgets('the deposit uses the minimum when 20 percent is lower', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The backpack: declared value 12,000, 20% is 2,400, minimum 5,000.
    final backpack = _noPhotos(
      FakeData.items.firstWhere((i) => i.id == 'item-7'),
    );
    final items = FakeItemRepository(items: [backpack]);
    final settings = FakeSettingsRepository(
      settings: const AppSettings(
        commissionRateBps: 1000,
        depositRateBps: 2000,
        lateFeeMultiplierX100: 150,
        minDepositAmount: 5000,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(items),
          settingsRepositoryProvider.overrideWithValue(settings),
          bookingRepositoryProvider.overrideWithValue(
            FakeBookingRepository(items: items, settings: settings),
          ),
        ],
        child: const MaterialApp(home: ItemDetailsScreen(itemId: 'item-7')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refundable deposit: NPR 5,000'), findsOneWidget);
  });

  testWidgets(
    'with the live backend the request button is replaced by a notice',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final camera = _noPhotos(FakeData.items.first);
      final items = FakeItemRepository(items: [camera]);
      final settings = FakeSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itemRepositoryProvider.overrideWithValue(items),
            settingsRepositoryProvider.overrideWithValue(settings),
            bookingRepositoryProvider.overrideWithValue(
              FakeBookingRepository(items: items, settings: settings),
            ),
            bookingRequestsEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: ItemDetailsScreen(itemId: 'item-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Send rental request'), findsNothing);
    },
  );
}
