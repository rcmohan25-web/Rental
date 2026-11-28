import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart' show AppException;
import 'package:rental_data/rental_data.dart';

Future<String?> errorCode(Future<Object?> Function() action) async {
  try {
    await action();
    return null;
  } on AppException catch (e) {
    return e.code;
  }
}

ImageUpload _photo() => ImageUpload(bytes: Uint8List.fromList([1, 2, 3]));

void main() {
  late FakeIdentityStore store;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late FakeKycRepository kyc;
  late FakeAdminKycRepository admin;

  setUp(() {
    store = FakeIdentityStore();
    auth = FakeAuthRepository(store: store);
    profiles = FakeProfileRepository(store: store);
    kyc = FakeKycRepository(store: store);
    admin = FakeAdminKycRepository(store: store);
  });

  group('auth', () {
    test('sign up signs the user in with kyc none', () async {
      final result = await auth.signUp(
        email: ' Mina@Example.test ',
        password: 'longenough',
        fullName: 'Mina Tamang',
      );
      expect(result.needsEmailConfirmation, isFalse);
      expect(auth.currentUserId, isNotNull);
      final profile = await profiles.getMyProfile();
      expect(profile.firstName, 'Mina');
      expect(profile.kycStatus, KycStatus.none);
      expect(profile.role, UserRole.user);
    });

    test('duplicate e-mail and short password are refused', () async {
      await auth.signUp(
        email: 'a@example.test',
        password: 'longenough',
        fullName: 'A',
      );
      expect(
        await errorCode(
          () => auth.signUp(
            email: 'A@example.test',
            password: 'longenough',
            fullName: 'A',
          ),
        ),
        'EMAIL_TAKEN',
      );
      expect(
        await errorCode(
          () => auth.signUp(
            email: 'b@example.test',
            password: 'short',
            fullName: 'B',
          ),
        ),
        'WEAK_PASSWORD',
      );
    });

    test('wrong password gives INVALID_CREDENTIALS, sign out clears', () async {
      expect(
        await errorCode(
          () => auth.signIn(email: 'admin@sapati.test', password: 'nope'),
        ),
        'INVALID_CREDENTIALS',
      );
      await auth.signIn(email: 'admin@sapati.test', password: 'admin12345');
      expect(auth.currentUserId, FakeIdentityStore.adminId);
      await auth.signOut();
      expect(auth.currentUserId, isNull);
    });

    test('watchUserId emits the current id and then changes', () async {
      final seen = <String?>[];
      final sub = auth.watchUserId().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await auth.signIn(email: 'admin@sapati.test', password: 'admin12345');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [null, FakeIdentityStore.adminId, null]);
    });
  });

  group('profile', () {
    test('signed out gives NOT_AUTHENTICATED', () async {
      expect(await errorCode(profiles.getMyProfile), 'NOT_AUTHENTICATED');
    });

    test('update writes name, phone and area', () async {
      await auth.signIn(email: 'admin@sapati.test', password: 'admin12345');
      final p = await profiles.updateMyProfile(
        fullName: 'New Name',
        phone: '9800000000',
        area: Area.bhaktapur,
      );
      expect(p.fullName, 'New Name');
      expect(p.phone, '9800000000');
      expect(p.area, Area.bhaktapur);
    });
  });

  group('ID check, end to end', () {
    Future<void> signUpUser() => auth.signUp(
          email: 'user@example.test',
          password: 'longenough',
          fullName: 'Test User',
        );

    test(
      'submit, admin rejects with reason, user resubmits, admin approves',
      () async {
        await signUpUser();
        final userId = auth.currentUserId!;
        final submitted = await kyc.submitKyc(
          idPhoto: _photo(),
          facePhoto: _photo(),
        );
        expect(submitted.status, KycStatus.pending);
        expect(
          await errorCode(
            () => kyc.submitKyc(idPhoto: _photo(), facePhoto: _photo()),
          ),
          'INVALID_STATE',
        );

        await auth.signIn(email: 'admin@sapati.test', password: 'admin12345');
        final pending = await admin.listPending();
        expect(pending.single.userId, userId);
        expect(
          await errorCode(
            () => admin.review(userId: userId, approve: false, reason: ' '),
          ),
          'REASON_REQUIRED',
        );
        await admin.review(userId: userId, approve: false, reason: 'Blurry');
        expect(await admin.listPending(), isEmpty);

        await auth.signIn(email: 'user@example.test', password: 'longenough');
        final rejected = await kyc.getMyKycStatus();
        expect(rejected.status, KycStatus.rejected);
        expect(rejected.reason, 'Blurry');
        await kyc.submitKyc(idPhoto: _photo(), facePhoto: _photo());
        expect((await kyc.getMyKycStatus()).reason, isNull);

        await auth.signIn(email: 'admin@sapati.test', password: 'admin12345');
        await admin.review(userId: userId, approve: true);
        await auth.signIn(email: 'user@example.test', password: 'longenough');
        expect((await profiles.getMyProfile()).kycStatus, KycStatus.verified);
      },
    );

    test('a normal user cannot use the admin repository', () async {
      await signUpUser();
      expect(await errorCode(admin.listPending), 'NOT_ADMIN');
    });
  });
}
