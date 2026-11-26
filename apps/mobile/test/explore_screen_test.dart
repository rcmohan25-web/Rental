import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental/features/explore/application/catalog_providers.dart';
import 'package:rental/features/explore/presentation/explore_screen.dart';
import 'package:rental_data/rental_data.dart';

/// Items without photos, so the test never touches the network or the image
/// cache plugin.
List<Item> _testItems() => [
      for (final item in FakeData.items.take(4))
        Item(
          id: item.id,
          lenderId: item.lenderId,
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
        ),
    ];

Widget _app(List<Item> items) => ProviderScope(
      overrides: [
        itemRepositoryProvider
            .overrideWithValue(FakeItemRepository(items: items)),
      ],
      child: const MaterialApp(home: ExploreScreen()),
    );

/// The default test screen is 800x600, so a list only builds the first card or
/// two and `find.text` cannot see the rest. A tall screen shows everything.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows the items from the repository', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(_testItems()));
    await tester.pumpAndSettle();

    expect(find.text('Sony Alpha A7 III Camera'), findsOneWidget);
    expect(find.text('Epson Full HD Projector'), findsOneWidget);
    expect(find.text('NPR 3,500 / day'), findsOneWidget);
  });

  testWidgets('category chip filters the list', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(_testItems()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Projectors'));
    await tester.pumpAndSettle();

    expect(find.text('Epson Full HD Projector'), findsOneWidget);
    expect(find.text('Sony Alpha A7 III Camera'), findsNothing);
  });

  testWidgets('search with no match shows the empty state', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(_testItems()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No items found'), findsOneWidget);
  });
}
