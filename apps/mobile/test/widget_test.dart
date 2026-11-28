import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental/app.dart';
import 'package:rental/features/auth/application/auth_providers.dart';
import 'package:rental_data/rental_data.dart';

void main() {
  testWidgets('a signed-out user lands on the welcome screen', (tester) async {
    final store = FakeIdentityStore(accounts: []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(store: store),
          ),
        ],
        child: const RentalApp(),
      ),
    );
    // Splash first, then the welcome screen after its short pause.
    expect(find.text('Rental'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
