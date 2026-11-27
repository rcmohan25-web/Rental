import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../image_upload.dart';
import '../kyc_repository.dart';
import 'supabase_helpers.dart';

class SupabaseKycRepository implements KycRepository {
  SupabaseKycRepository(this._client);

  final SupabaseClient _client;

  KycStatusInfo _info(Map<String, dynamic> json) => KycStatusInfo(
        status: KycStatus.fromWire(json['kyc_status'] as String),
        reason: json['reason'] as String?,
        submittedAt: json['submitted_at'] == null
            ? null
            : DateTime.parse(json['submitted_at'] as String),
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at'] as String),
      );

  @override
  Future<KycStatusInfo> getMyKycStatus() => guarded(() async {
        return _info(asRow(await _client.rpc('get_my_kyc_status')));
      });

  @override
  Future<KycStatusInfo> submitKyc({
    required ImageUpload idPhoto,
    required ImageUpload facePhoto,
  }) =>
      guarded(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw const AppException(
            'Please sign in to continue.',
            code: 'NOT_AUTHENTICATED',
          );
        }
        // Private bucket, the user's own folder, a new random name per attempt.
        final stamp = randomId();
        final idPath = '$userId/id-$stamp.${extensionFor(idPhoto)}';
        final facePath = '$userId/face-$stamp.${extensionFor(facePhoto)}';
        final bucket = _client.storage.from('kyc');
        await bucket.uploadBinary(
          idPath,
          idPhoto.bytes,
          fileOptions: FileOptions(contentType: idPhoto.contentType),
        );
        await bucket.uploadBinary(
          facePath,
          facePhoto.bytes,
          fileOptions: FileOptions(contentType: facePhoto.contentType),
        );
        final result = await _client.rpc(
          'submit_kyc',
          params: {'p_id_path': idPath, 'p_face_path': facePath},
        );
        return _info(asRow(result));
      });
}
