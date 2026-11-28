import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

import '../application/auth_error_messages.dart';
import '../application/auth_providers.dart';

/// Step 1 of sign-up. Step 2 is the optional ID upload (`/sign-up/id`).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _checkEmail = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
          );
      if (!mounted) return;
      if (result.needsEmailConfirmation) {
        setState(() {
          _busy = false;
          _checkEmail = true;
        });
      } else {
        context.go('/sign-up/id');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: SafeArea(
        child: _checkEmail ? _buildCheckEmail(context) : _buildForm(),
      ),
    );
  }

  Widget _buildCheckEmail(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 56),
          const SizedBox(height: 12),
          Text(
            'Check your e-mail',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a link to ${_email.text.trim()}. Open it, then log in.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Go to log in',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
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
                label: 'E-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.next,
                helperText: 'At least 8 characters.',
                validator: validatePassword,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirm password',
                controller: _confirm,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v == _password.text ? null : 'Passwords do not match.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Create account',
                loading: _busy,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
