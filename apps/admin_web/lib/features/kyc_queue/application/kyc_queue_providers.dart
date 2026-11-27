import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

import '../../shell/application/admin_providers.dart';

/// IDs waiting for an admin, oldest first. Invalidate to reload (this also
/// fetches fresh signed photo URLs).
final pendingKycProvider = FutureProvider.autoDispose<List<PendingKyc>>(
  (ref) => ref.watch(adminKycRepositoryProvider).listPending(),
);
