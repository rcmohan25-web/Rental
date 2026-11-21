import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental/app.dart';

void main() {
  testWidgets('skeleton home opens and lists placeholders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RentalApp()));
    await tester.pumpAndSettle();

    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Phase 0 skeleton'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });
}
