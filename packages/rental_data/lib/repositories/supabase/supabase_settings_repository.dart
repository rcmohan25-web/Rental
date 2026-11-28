import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../settings_repository.dart';
import 'supabase_helpers.dart';

/// Reads the whitelisted settings through `get_public_settings` (the
/// `app_settings` table itself is admin-only).
class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppSettings> getSettings() => guarded(() async {
        final values = asRow(await _client.rpc('get_public_settings'));
        try {
          return AppSettings.fromKeyValues(values);
        } on FormatException {
          // A required rate is missing or malformed: never guess a number.
          throw const AppException(
            'Settings unavailable.',
            code: 'SETTING_UNAVAILABLE',
          );
        }
      });
}
