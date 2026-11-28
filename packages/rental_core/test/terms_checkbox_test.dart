import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the label and the honesty line, reports the tick', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => TermsCheckbox(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    expect(find.text('I have read and accept the terms'), findsOneWidget);
    expect(find.text(HonestyTexts.tickIsAcceptance), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('read link and error text appear only when given', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        TermsCheckbox(
          value: false,
          onChanged: (_) {},
          onReadTerms: () => opened++,
          errorText: 'Tick the box to continue.',
        ),
      ),
    );
    expect(find.text('Tick the box to continue.'), findsOneWidget);
    await tester.tap(find.text('Read the terms'));
    expect(opened, 1);

    await tester.pumpWidget(
      host(TermsCheckbox(value: false, onChanged: (_) {})),
    );
    expect(find.text('Read the terms'), findsNothing);
    expect(find.text('Tick the box to continue.'), findsNothing);
  });

  testWidgets('a disabled box ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        TermsCheckbox(value: false, enabled: false, onChanged: (_) => taps++),
      ),
    );
    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
