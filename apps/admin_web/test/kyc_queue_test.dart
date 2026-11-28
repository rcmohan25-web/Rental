import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_admin/features/kyc_queue/presentation/kyc_queue_screen.dart';
import 'package:rental_admin/features/shell/application/admin_providers.dart';
import 'package:rental_data/rental_data.dart';

void main() {
  testWidgets('the queue shows a pending ID and approving empties it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = FakeIdentityStore(
      accounts: [
        FakeAccount(
          id: FakeIdentityStore.adminId,
          email: 'admin@sapati.test',
          password: 'admin12345',
          fullName: 'Sapati Admin',
          role: UserRole.admin,
          kyc: KycStatus.verified,
        ),
        FakeAccount(
          id: 'u1',
          email: 'mina@example.test',
          password: 'longenough',
          fullName: 'Mina Tamang',
          kyc: KycStatus.pending,
          submittedAt: DateTime.utc(2026, 11, 26, 4),
        ),
      ],
      currentUserId: FakeIdentityStore.adminId,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminKycRepositoryProvider.overrideWithValue(
            FakeAdminKycRepository(store: store),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KycQueueScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mina Tamang'), findsOneWidget);

    await tester.tap(find.text('Mark as checked'));
    await tester.pumpAndSettle();

    expect(find.text('No IDs waiting'), findsOneWidget);
    expect(store.accounts.last.kyc, KycStatus.verified);
  });
}
