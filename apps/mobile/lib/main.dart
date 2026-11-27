import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_data/rental_data.dart';

import 'app.dart';
import 'config/app_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without SUPABASE_URL and SUPABASE_ANON_KEY (--dart-define-from-file) the
  // app runs on the in-memory fakes, so every screen can be tried offline.
  if (AppEnv.isConfigured) {
    await RentalBackend.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: RentalApp()));
}
