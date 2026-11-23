import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart';

void main() {
  test('theme uses brand colours', () {
    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, BrandColors.navy);
    expect(theme.colorScheme.secondary, BrandColors.hotPink);
    expect(theme.scaffoldBackgroundColor, BrandColors.background);
  });

  test('NPR formatting', () {
    expect(Formatters.npr(10500), 'NPR 10,500');
    expect(Formatters.npr(160000), 'NPR 160,000');
  });

  testWidgets('status chip shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(label: 'Verified', tone: StatusTone.success),
        ),
      ),
    );
    expect(find.text('Verified'), findsOneWidget);
  });
}
