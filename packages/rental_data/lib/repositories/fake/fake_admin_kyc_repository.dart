import 'package:rental_core/rental_core.dart' show AppException;

import '../../models/models.dart';
import '../admin_kyc_repository.dart';
import 'fake_identity_store.dart';

class FakeAdminKycRepository implements AdminKycRepository {
  FakeAdminKycRepository({
    FakeIdentityStore? store,
    this.latency = Duration.zero,
  }) : store = store ?? FakeIdentityStore();

  final FakeIdentityStore store;
  final Duration latency;

  void _requireAdmin() {
    if (store.me.role != UserRole.admin) {
      throw const AppException('Admins only.', code: 'NOT_ADMIN');
    }
  }

  @override
  Future<List<PendingKyc>> listPending() async {
    await Future<void>.delayed(latency);
    _requireAdmin();
    final pending = store.accounts
        .where((a) => a.kyc == KycStatus.pending && a.submittedAt != null)
        .toList()
      ..sort((a, b) => a.submittedAt!.compareTo(b.submittedAt!));
    return [
      for (final a in pending)
        PendingKyc(
          userId: a.id,
          displayName: a.fullName,
          submittedAt: a.submittedAt!,
          idPhotoUrl: 'https://picsum.photos/seed/id-${a.id}/800/500',
          facePhotoUrl: 'https://picsum.photos/seed/face-${a.id}/600/600',
        ),
    ];
  }

  @override
  Future<void> review({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    await Future<void>.delayed(latency);
    _requireAdmin();
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw const AppException(
        'Please give a reason.',
        code: 'REASON_REQUIRED',
      );
    }
    final matches = store.accounts.where((a) => a.id == userId);
    if (matches.isEmpty || matches.first.kyc != KycStatus.pending) {
      throw const AppException(
        'This ID is not waiting for review.',
        code: 'INVALID_STATE',
      );
    }
    final account = matches.first;
    account
      ..kyc = approve ? KycStatus.verified : KycStatus.rejected
      ..kycReason = approve ? null : reason!.trim()
      ..reviewedAt = DateTime.now().toUtc();
  }
}
