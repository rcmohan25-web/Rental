import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../profile_repository.dart';
import 'supabase_helpers.dart';

/// Reads `profiles` and the owner-only `profile_private`. The Profile model
/// still uses its Phase 0 key names, so `status` is mapped to `account_status`
/// here and the model stays frozen.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException(
        'Please sign in to continue.',
        code: 'NOT_AUTHENTICATED',
      );
    }
    return id;
  }

  @override
  Future<Profile> getMyProfile() => guarded(() async {
    final id = _userId();
    final row = asRow(
      await _client.from('profiles').select().eq('id', id).single(),
    );
    final private = await _client
        .from('profile_private')
        .select('phone, area')
        .eq('user_id', id)
        .maybeSingle();
    return Profile.fromJson({
      'id': row['id'],
      'display_name': row['display_name'],
      'role': row['role'],
      'account_status': row['status'],
      'kyc_status': row['kyc_status'],
      'created_at': row['created_at'],
      'phone': private?['phone'],
      'area': parseArea(private?['area'])?.wire,
    });
  });

  @override
  Future<Profile> updateMyProfile({
    required String fullName,
    String? phone,
    Area? area,
  }) => guarded(() async {
    final id = _userId();
    await _client
        .from('profiles')
        .update({'display_name': fullName.trim()})
        .eq('id', id);
    final cleanPhone = (phone == null || phone.trim().isEmpty)
        ? null
        : phone.trim();
    // Update first: the client may not write user_id on an existing row.
    final updated = await _client
        .from('profile_private')
        .update({'phone': cleanPhone, 'area': area?.wire})
        .eq('user_id', id)
        .select();
    if (updated.isEmpty) {
      await _client.from('profile_private').insert({
        'user_id': id,
        'phone': cleanPhone,
        'area': area?.wire,
      });
    }
    return getMyProfile();
  });
}
