import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental/features/auth/application/auth_providers.dart';
import 'package:rental/features/profile_kyc/application/profile_providers.dart';
import 'package:rental/features/profile_kyc/presentation/widgets/kyc_status_banner.dart';
import 'package:rental_data/rental_data.dart';

Widget _banner(KycStatusInfo info) => MaterialApp(
      home: Scaffold(
        body: KycStatusBanner(info: info, onAction: () {}),
      ),
    );

void main() {
  testWidgets('banner explains each ID status', (tester) async {
    await tester.pumpWidget(
      _banner(const KycStatusInfo(status: KycStatus.none)),
    );
    expect(find.text('ID not submitted'), findsOneWidget);
    expect(find.text('Verify identity'), findsOneWidget);

    await tester.pumpWidget(
      _banner(const KycStatusInfo(status: KycStatus.pending)),
    );
    expect(find.text('Waiting for an admin'), findsOneWidget);
    expect(find.text('Verify identity'), findsNothing);

    await tester.pumpWidget(
      _banner(const KycStatusInfo(status: KycStatus.verified)),
    );
    expect(find.text('ID checked by an admin'), findsOneWidget);

    await tester.pumpWidget(
      _banner(
        const KycStatusInfo(status: KycStatus.rejected, reason: 'Too blurry'),
      ),
    );
    expect(find.text('ID not accepted'), findsOneWidget);
    expect(find.text('Reason: Too blurry'), findsOneWidget);
    expect(find.text('Submit again'), findsOneWidget);
  });

  test('profile providers read through the repositories', () async {
    final store = FakeIdentityStore(currentUserId: FakeIdentityStore.adminId);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(store: store),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(store: store),
        ),
        kycRepositoryProvider.overrideWithValue(
          FakeKycRepository(store: store),
        ),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(myProfileProvider.future);
    expect(profile.isAdmin, isTrue);
    final kyc = await container.read(myKycStatusProvider.future);
    expect(kyc.status, KycStatus.verified);
  });
}
