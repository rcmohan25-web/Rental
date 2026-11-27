import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_kyc_repository.dart';
import 'supabase_helpers.dart';

/// Admin side of the ID check. Reads are allowed by the admin RLS policies on
/// `kyc_submissions` and the `kyc` bucket; the decision goes through the
/// `admin_review_kyc` RPC, which audits it.
class SupabaseAdminKycRepository implements AdminKycRepository {
  SupabaseAdminKycRepository(this._client);

  final SupabaseClient _client;

  static const int _signedUrlSeconds = 300;

  @override
  Future<List<PendingKyc>> listPending() => guarded(() async {
        final rows = await _client
            .from('kyc_submissions')
            .select(
              'user_id, id_path, face_path, submitted_at, profiles!user_id(display_name)',
            )
            .eq('status', 'pending')
            .order('submitted_at', ascending: true);
        final bucket = _client.storage.from('kyc');
        return Future.wait([
          for (final raw in rows)
            () async {
              final row = asRow(raw);
              final profile = row['profiles'];
              final name = profile is Map ? profile['display_name'] : null;
              return PendingKyc(
                userId: row['user_id'] as String,
                displayName: (name as String?) ?? 'Unnamed user',
                submittedAt: DateTime.parse(row['submitted_at'] as String),
                idPhotoUrl: await bucket.createSignedUrl(
                  row['id_path'] as String,
                  _signedUrlSeconds,
                ),
                facePhotoUrl: await bucket.createSignedUrl(
                  row['face_path'] as String,
                  _signedUrlSeconds,
                ),
              );
            }(),
        ]);
      });

  @override
  Future<void> review({
    required String userId,
    required bool approve,
    String? reason,
  }) =>
      guarded(() async {
        await _client.rpc(
          'admin_review_kyc',
          params: {
            'p_user_id': userId,
            'p_decision': approve ? 'verified' : 'rejected',
            'p_reason': reason,
          },
        );
      });
}
