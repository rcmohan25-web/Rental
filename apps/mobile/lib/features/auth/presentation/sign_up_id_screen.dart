import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../profile_kyc/presentation/widgets/id_upload_form.dart';

/// Step 2 of sign-up: optional. "Do it later" leads to the app; the ID can be
/// added from Profile > Verify identity, and the app asks for it before the
/// first request or listing.
class SignUpIdScreen extends StatelessWidget {
  const SignUpIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your identity'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.go('/explore'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Do it later'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'You can browse without an ID, but you need one before you '
              'borrow or lend. You can add it now or later.',
            ),
            const SizedBox(height: 16),
            IdUploadForm(onSubmitted: () => context.go('/explore')),
          ],
        ),
      ),
    );
  }
}
