import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

/// The one place the admin panel picks its repositories.
final adminAuthRepositoryProvider = Provider<AuthRepository>(
  (ref) => RentalBackend.auth(),
);

final adminProfileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => RentalBackend.profiles(),
);

final adminKycRepositoryProvider = Provider<AdminKycRepository>(
  (ref) => RentalBackend.adminKyc(),
);

/// Runs the router redirect again when the admin signs in or out.
class AdminAuthRefresh extends ChangeNotifier {
  AdminAuthRefresh(Stream<String?> userIds) {
    _subscription = userIds.listen((_) => notifyListeners());
  }

  late final StreamSubscription<String?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final adminAuthRefreshProvider = Provider<AdminAuthRefresh>((ref) {
  final refresh = AdminAuthRefresh(
    ref.watch(adminAuthRepositoryProvider).watchUserId(),
  );
  ref.onDispose(refresh.dispose);
  return refresh;
});
