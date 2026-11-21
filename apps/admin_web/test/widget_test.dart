import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_admin/app.dart';

void main() {
  testWidgets('admin shell opens with the Rental Admin title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RentalAdminApp()));
    await tester.pumpAndSettle();

    expect(find.text('Rental Admin'), findsOneWidget);
    expect(find.text('Admin overview'), findsOneWidget);
  });
}
