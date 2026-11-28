/// What happened after a sign-up.
class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});

  /// True when the project requires e-mail confirmation: the account exists
  /// but there is no session until the user opens the link in the e-mail.
  final bool needsEmailConfirmation;
}

/// E-mail and password accounts. Failures throw AppException with one of the
/// client codes INVALID_CREDENTIALS, EMAIL_TAKEN, WEAK_PASSWORD, EMAIL_NOT_CONFIRMED
/// or NETWORK (these are not RPC codes, see docs/api-contract.md section 11).
abstract class AuthRepository {
  /// Null when signed out.
  String? get currentUserId;

  /// Emits the current user id first, then again on every sign-in or sign-out.
  Stream<String?> watchUserId();

  /// The profile row is created by the database trigger from [fullName].
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
