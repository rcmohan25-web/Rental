import 'package:rental_core/rental_core.dart';

const String _generic = 'Something went wrong. Please try again.';

const Map<String, String> _messages = {
  'INVALID_CREDENTIALS': 'Wrong e-mail or password.',
  'EMAIL_TAKEN': 'This e-mail already has an account. Try logging in.',
  'WEAK_PASSWORD': 'Please choose a password with at least 8 characters.',
  'EMAIL_NOT_CONFIRMED': 'Please confirm your e-mail first, then log in.',
  'NETWORK': 'No connection. Check your internet and try again.',
  'ACCOUNT_RESTRICTED': 'Your account is restricted. Please contact support.',
};

/// Text that is safe to show for any sign-in, sign-up or profile error.
String friendlyAuthError(Object error) {
  if (error is AppException) {
    final code = error.code;
    if (code != null && _messages.containsKey(code)) return _messages[code]!;
  }
  return _generic;
}

/// Simple e-mail check for the forms (the server still has the last word).
String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your e-mail.';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  return ok ? null : 'Enter a valid e-mail.';
}

String? validatePassword(String? value) {
  if ((value ?? '').length < 8) return 'Use at least 8 characters.';
  return null;
}
