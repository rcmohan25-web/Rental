import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_admin/app.dart';
import 'package:rental_admin/features/shell/application/admin_providers.dart';
import 'package:rental_data/rental_data.dart';

ProviderScope _app(FakeIdentityStore store) => ProviderScope(
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(
          FakeAuthRepository(store: store),
        ),
        adminProfileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(store: store),
        ),
      ],
      child: const RentalAdminApp(),
    );

void main() {
  testWidgets('a signed-in admin sees the shell with the overview', (
    tester,
  ) async {
    final store = FakeIdentityStore(currentUserId: FakeIdentityStore.adminId);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Rental Admin'), findsOneWidget);
    expect(find.text('Admin overview'), findsOneWidget);
  });

  testWidgets('a signed-out visitor sees the login page', (tester) async {
    await tester.pumpWidget(_app(FakeIdentityStore()));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in with your Sapati staff account.'),
      findsOneWidget,
    );
    expect(find.text('Admin overview'), findsNothing);
  });

  testWidgets('a normal user is refused and signed out', (tester) async {
    final store = FakeIdentityStore(
      accounts: [
        FakeAccount(
          id: 'u1',
          email: 'user@example.test',
          password: 'longenough',
          fullName: 'Normal User',
        ),
      ],
      currentUserId: 'u1',
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('This account is not a Sapati admin.'), findsOneWidget);
    expect(store.currentUserId, isNull);
  });
}
