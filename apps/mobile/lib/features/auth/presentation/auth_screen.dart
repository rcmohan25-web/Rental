import 'package:flutter/material.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Mohan).
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: const PlaceholderView(
        title: 'Sign in',
        owner: 'Mohan',
        description:
            'Splash, landing, sign-up (with optional ID step and a "Do it later" link), login.',
      ),
    );
  }
}
