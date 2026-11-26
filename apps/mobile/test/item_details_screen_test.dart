import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental/features/explore/application/catalog_providers.dart';
import 'package:rental/features/item_details/presentation/item_details_screen.dart';
import 'package:rental_data/rental_data.dart';

Item _cameraWithoutPhotos() {
  final item = FakeData.items.first;
  return Item(
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
}

Widget _app({String? itemId}) {
  final items = FakeItemRepository(items: [_cameraWithoutPhotos()]);
  final settings = FakeSettingsRepository();
  return ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(items),
      settingsRepositoryProvider.overrideWithValue(settings),
      bookingRepositoryProvider.overrideWithValue(
        FakeBookingRepository(
          items: items,
          settings: settings,
          clock: () => DateTime(2026, 11, 1),
        ),
      ),
    ],
    child: MaterialApp(home: ItemDetailsScreen(itemId: itemId)),
  );
}

/// The default test screen is 800x600, so a list only builds the first card or
/// two and `find.text` cannot see the rest. A tall screen shows everything.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows price and the deposit separately', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(itemId: 'item-1'));
    await tester.pumpAndSettle();

    expect(find.text('Sony Alpha A7 III Camera'), findsOneWidget);
    expect(find.text('NPR 3,500 / day'), findsOneWidget);
    // 20% of the declared value NPR 160,000 (rate approved in contract v0.3).
    expect(find.text('Refundable deposit: NPR 32,000'), findsOneWidget);
    // No dates yet, so no breakdown and no request button.
    expect(find.text('Cost breakdown'), findsNothing);
    expect(find.text('Send rental request'), findsNothing);
  });

  testWidgets('shows the dates already booked', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(itemId: 'item-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Already booked:'), findsOneWidget);
  });

  testWidgets('unknown item shows a clear message', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(itemId: 'missing'));
    await tester.pumpAndSettle();

    expect(find.text('This item is no longer available.'), findsOneWidget);
  });

  testWidgets('no item id shows the empty state', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('No item selected'), findsOneWidget);
  });
}
