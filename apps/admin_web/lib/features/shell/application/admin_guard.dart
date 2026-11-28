import 'package:rental_data/rental_data.dart';

/// Route guard for the admin panel: only signed-in accounts with
/// profiles.role = 'admin' (and an active account) get past the login page.
/// The database enforces the same rule on every admin RPC and read, so this is
/// about showing the right screen, not about security.
class AdminGate {
  AdminGate(this._auth, this._profiles);

  final AuthRepository _auth;
  final ProfileRepository _profiles;

  String? _checkedUserId;
  bool _isAdmin = false;
  bool _justDenied = false;

  /// Returns the path to go to, or null to stay.
  Future<String?> redirect(String location) async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      _checkedUserId = null;
      _isAdmin = false;
      if (_justDenied) {
        return location == '/login?denied=1' ? null : '/login?denied=1';
      }
      return location == '/login' ? null : '/login';
    }
    if (_checkedUserId != userId) {
      _justDenied = false;
      try {
        final profile = await _profiles.getMyProfile();
        _isAdmin = profile.isAdmin && profile.isActive;
      } catch (_) {
        _isAdmin = false;
      }
      _checkedUserId = userId;
    }
    if (!_isAdmin) {
      _checkedUserId = null;
      _justDenied = true;
      await _auth.signOut();
      return '/login?denied=1';
    }
    return location.startsWith('/login') ? '/' : null;
  }
}
