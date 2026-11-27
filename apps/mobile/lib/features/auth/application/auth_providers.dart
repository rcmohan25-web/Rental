import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

/// The one place the mobile app picks its auth repository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => RentalBackend.auth(),
);

/// Tells go_router to run its redirect again when the user signs in or out.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Stream<String?> userIds) {
    _subscription = userIds.listen((_) => notifyListeners());
  }

  late final StreamSubscription<String?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final authRefreshProvider = Provider<AuthRefresh>((ref) {
  final refresh = AuthRefresh(ref.watch(authRepositoryProvider).watchUserId());
  ref.onDispose(refresh.dispose);
  return refresh;
});

/// Screens a signed-out user may see.
const Set<String> _signedOutPaths = {
  '/splash',
  '/welcome',
  '/login',
  '/sign-up',
};

/// Screens a signed-in user is moved away from. '/sign-up' is not listed so the
/// optional ID step right after sign-up is not skipped.
const Set<String> _leaveWhenSignedIn = {'/splash', '/welcome', '/login'};

/// Auth guard for the mobile router. Returns the path to go to, or null.
String? mobileRedirect({required String? userId, required String location}) {
  final signedIn = userId != null;
  if (!signedIn && !_signedOutPaths.contains(location)) return '/welcome';
  if (signedIn && _leaveWhenSignedIn.contains(location)) return '/explore';
  return null;
}
