import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

void main() {
  test('setting keys are unique and include the minimum deposit', () {
    expect(SettingKeys.all.toSet().length, SettingKeys.all.length);
    expect(SettingKeys.all, contains('min_deposit_amount'));
    expect(SettingKeys.all, contains('commission_rate'));
  });

  test('payment channels match the accepted manual channels', () {
    expect(
      PaymentChannel.values.map((c) => c.label).toList(),
      ['eSewa', 'Khalti', 'Bank transfer'],
    );
    for (final channel in PaymentChannel.values) {
      expect(channel.qrAsset, startsWith('assets/payment_qr/'));
    }
  });

  testWidgets('empty state shows its title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: 'No items', message: 'Nothing listed yet'),
        ),
      ),
    );
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Nothing listed yet'), findsOneWidget);
  });

  testWidgets('error state calls onRetry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ErrorState(onRetry: () => retried++)),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('primary button ignores taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Pay',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
