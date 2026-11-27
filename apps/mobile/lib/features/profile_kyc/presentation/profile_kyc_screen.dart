import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../auth/application/auth_error_messages.dart';
import '../../auth/application/auth_providers.dart';
import '../application/profile_providers.dart';
import 'widgets/kyc_status_banner.dart';

/// Profile tab: edit name, phone and area, see the ID status, sign out.
class ProfileKycScreen extends ConsumerWidget {
  const ProfileKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const LoadingView(message: 'Loading profile'),
        error: (e, _) =>
            ErrorState(onRetry: () => ref.invalidate(myProfileProvider)),
        data: (p) => _ProfileBody(profile: p),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late Area? _area = widget.profile.area;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            fullName: _name.text,
            phone: _phone.text,
            area: _area,
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = ref.watch(myKycStatusProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        kyc.when(
          loading: () => const SizedBox(height: 96, child: LoadingView()),
          error: (e, _) => ErrorState(
            message: 'Could not load your ID status.',
            onRetry: () => ref.invalidate(myKycStatusProvider),
          ),
          data: (info) => KycStatusBanner(
            info: info,
            onAction: () => context.push('/profile/verify-id'),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Full name',
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Phone number',
                controller: _phone,
                keyboardType: TextInputType.phone,
                helperText: 'Shared with the other person only after '
                    'payment is verified.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Area>(
                initialValue: _area,
                decoration: const InputDecoration(labelText: 'Area'),
                items: [
                  for (final area in Area.values)
                    DropdownMenuItem(value: area, child: Text(area.label)),
                ],
                onChanged: (value) => setState(() => _area = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save', loading: _saving, onPressed: _save),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
        ),
        const SizedBox(height: 16),
        const Text(
          '${AppConstants.appName} is run by ${AppConstants.companyName}. '
          'Support: ${AppConstants.supportEmail}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: BrandColors.textMuted),
        ),
      ],
    );
  }
}
