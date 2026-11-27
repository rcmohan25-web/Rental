import 'package:rental_core/rental_core.dart' show AppException;

import '../../models/models.dart';
import '../image_upload.dart';
import '../kyc_repository.dart';
import 'fake_identity_store.dart';

class FakeKycRepository implements KycRepository {
  FakeKycRepository({FakeIdentityStore? store, this.latency = Duration.zero})
      : store = store ?? FakeIdentityStore();

  final FakeIdentityStore store;
  final Duration latency;

  KycStatusInfo _info(FakeAccount a) => KycStatusInfo(
        status: a.kyc,
        reason: a.kyc == KycStatus.rejected ? a.kycReason : null,
        submittedAt: a.submittedAt,
        reviewedAt: a.reviewedAt,
      );

  @override
  Future<KycStatusInfo> getMyKycStatus() async {
    await Future<void>.delayed(latency);
    return _info(store.me);
  }

  @override
  Future<KycStatusInfo> submitKyc({
    required ImageUpload idPhoto,
    required ImageUpload facePhoto,
  }) async {
    await Future<void>.delayed(latency);
    final me = store.me;
    if (me.kyc != KycStatus.none && me.kyc != KycStatus.rejected) {
      throw const AppException(
        'Your ID is already with an admin.',
        code: 'INVALID_STATE',
      );
    }
    if (idPhoto.bytes.isEmpty || facePhoto.bytes.isEmpty) {
      throw const AppException(
        'Both photos are needed.',
        code: 'EVIDENCE_MISSING',
      );
    }
    me
      ..kyc = KycStatus.pending
      ..kycReason = null
      ..reviewedAt = null
      ..submittedAt = DateTime.now().toUtc();
    return _info(me);
  }
}
