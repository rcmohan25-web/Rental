import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_data/rental_data.dart';

import 'app.dart';
import 'config/app_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without SUPABASE_URL and SUPABASE_ANON_KEY the panel runs on the in-memory
  // fakes (sign in with admin@sapati.test / admin12345).
  if (AppEnv.isConfigured) {
    await RentalBackend.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: RentalAdminApp()));
}
