import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_repository.dart';
import 'supabase_helpers.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> watchUserId() async* {
    yield currentUserId;
    yield* _client.auth.onAuthStateChange.map((s) => s.session?.user.id);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => guarded(() async {
    // The database trigger creates the profile from display_name.
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': fullName.trim()},
    );
    return SignUpResult(needsEmailConfirmation: response.session == null);
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      guarded(
        () => _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> signOut() => guarded(_client.auth.signOut);
}
