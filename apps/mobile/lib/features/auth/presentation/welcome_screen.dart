import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Landing screen for signed-out users.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: BrandColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Borrow what you need. Lend what you do not use. In '
                'Kathmandu, Lalitpur and Bhaktapur.',
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Create account',
                onPressed: () => context.go('/sign-up'),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Log in',
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Run by ${AppConstants.companyName}. ${HonestyTexts.manualPayment}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: BrandColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
