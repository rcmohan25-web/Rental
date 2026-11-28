import 'package:rental_core/rental_core.dart' show AppException;

import '../auth_repository.dart';
import 'fake_identity_store.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({FakeIdentityStore? store, this.latency = Duration.zero})
      : store = store ?? FakeIdentityStore();

  final FakeIdentityStore store;
  final Duration latency;

  @override
  String? get currentUserId => store.currentUserId;

  @override
  Stream<String?> watchUserId() async* {
    yield store.currentUserId;
    yield* store.changes;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await Future<void>.delayed(latency);
    final clean = email.trim().toLowerCase();
    if (store.byEmail(clean) != null) {
      throw const AppException(
        'This e-mail already has an account.',
        code: 'EMAIL_TAKEN',
      );
    }
    if (password.length < 8) {
      throw const AppException(
        'Password must be at least 8 characters.',
        code: 'WEAK_PASSWORD',
      );
    }
    final account = FakeAccount(
      id: store.nextId(),
      email: clean,
      password: password,
      fullName: fullName.trim(),
    );
    store.accounts.add(account);
    store.setCurrent(account.id);
    return const SignUpResult(needsEmailConfirmation: false);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(latency);
    final account = store.byEmail(email);
    if (account == null || account.password != password) {
      throw const AppException(
        'Wrong e-mail or password.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    store.setCurrent(account.id);
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(latency);
    store.setCurrent(null);
  }
}
