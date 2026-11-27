import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../application/profile_providers.dart';
import 'widgets/id_upload_form.dart';
import 'widgets/kyc_status_banner.dart';

/// Profile > Verify identity. Shows the form when no ID is with an admin,
/// otherwise the current status.
class VerifyIdScreen extends ConsumerWidget {
  const VerifyIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(myKycStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify identity')),
      body: status.when(
        loading: () => const LoadingView(message: 'Checking your ID status'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(myKycStatusProvider)),
        data: (info) {
          final canSubmit = info.status == KycStatus.none ||
              info.status == KycStatus.rejected;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              KycStatusBanner(info: info),
              const SizedBox(height: 16),
              if (canSubmit)
                IdUploadForm(
                  onSubmitted: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID submitted.')),
                    );
                    context.pop();
                  },
                )
              else
                SecondaryButton(
                  label: 'Back to profile',
                  onPressed: () => context.pop(),
                ),
            ],
          );
        },
      ),
    );
  }
}
