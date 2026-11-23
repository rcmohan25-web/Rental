import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(Srijan, Phase 1): Supabase.initialize(...) using AppEnv once the
  // Supabase repositories exist.
  runApp(const ProviderScope(child: RentalApp()));
}
