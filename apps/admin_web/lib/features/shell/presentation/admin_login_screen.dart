import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

import '../application/admin_providers.dart';

/// Sign-in page of Rental Admin. Only Sapati staff accounts get further.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({this.denied = false, super.key});

  /// True when a signed-in account was refused because it is not an admin.
  final bool denied;

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminAuthRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      // The router redirect takes it from here.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppException && e.code == 'INVALID_CREDENTIALS'
            ? 'Wrong e-mail or password.'
            : 'Could not sign in. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ??
        (widget.denied ? 'This account is not a Sapati admin.' : null);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppConstants.adminTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text('Sign in with your Sapati staff account.'),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'E-mail',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter your e-mail.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      obscureText: true,
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Enter your password.' : null,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(color: BrandColors.danger),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Sign in',
                      loading: _busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
