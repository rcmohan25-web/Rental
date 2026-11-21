import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_core/rental_core.dart';

import 'router/admin_router.dart';

class RentalAdminApp extends ConsumerWidget {
  const RentalAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.adminTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(adminRouterProvider),
    );
  }
}
