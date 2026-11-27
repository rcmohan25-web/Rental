import 'dart:math';

import 'package:rental_core/rental_core.dart' show AppException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../image_upload.dart';

final RegExp _codePattern = RegExp(r'^[A-Z][A-Z0-9_]+$');

/// Turns any Supabase, storage, auth or network error into an AppException.
/// A failed RPC raises `RAISE EXCEPTION '<CODE>'`, so the PostgREST message IS
/// the contract code (docs/api-contract.md section 1, "Error transport").
AppException mapError(Object error) {
  if (error is AppException) return error;
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (_codePattern.hasMatch(message)) {
      return AppException(message, code: message);
    }
    if (error.code == '42501') {
      return const AppException('Not allowed.', code: 'NOT_ALLOWED');
    }
    if (error.code == '23P01') {
      return const AppException('Dates taken.', code: 'DATES_TAKEN');
    }
    return AppException(
      'Something went wrong. Please try again.',
      code: 'UNKNOWN',
    );
  }
  if (error is StorageException) {
    final tooBig = error.statusCode == '413';
    return AppException(
      tooBig
          ? 'This photo is too large. Please choose a smaller one.'
          : 'The photo could not be uploaded. Please try again.',
      code: tooBig ? 'IMAGE_TOO_LARGE' : 'UPLOAD_FAILED',
    );
  }
  if (error is AuthException) return _mapAuth(error);
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('TimeoutException')) {
    return const AppException('No connection.', code: 'NETWORK');
  }
  return const AppException(
    'Something went wrong. Please try again.',
    code: 'UNKNOWN',
  );
}

AppException _mapAuth(AuthException e) {
  final text = '${e.code ?? ''} ${e.message}'.toLowerCase();
  if (text.contains('invalid_credentials') ||
      text.contains('invalid login credentials')) {
    return const AppException(
      'Wrong e-mail or password.',
      code: 'INVALID_CREDENTIALS',
    );
  }
  if (text.contains('already registered') ||
      text.contains('user_already_exists') ||
      text.contains('email_exists')) {
    return const AppException('E-mail already used.', code: 'EMAIL_TAKEN');
  }
  if (text.contains('weak_password') || text.contains('password should')) {
    return const AppException('Weak password.', code: 'WEAK_PASSWORD');
  }
  if (text.contains('email_not_confirmed') ||
      text.contains('email not confirmed')) {
    return const AppException(
      'Confirm your e-mail first.',
      code: 'EMAIL_NOT_CONFIRMED',
    );
  }
  return const AppException(
    'Something went wrong. Please try again.',
    code: 'UNKNOWN',
  );
}

/// Runs [action] and maps every error with [mapError].
Future<T> guarded<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw mapError(e);
  }
}

final Random _random = Random.secure();

/// 128 random bits as hex. Used in storage file names.
String randomId() => List<String>.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

String extensionFor(ImageUpload upload) => switch (upload.contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };

/// `profile_private.area` holds the wire value ('lalitpur'). Tolerates labels.
Area? parseArea(Object? value) {
  if (value is! String) return null;
  final lower = value.trim().toLowerCase();
  for (final area in Area.values) {
    if (area.wire == lower) return area;
  }
  return Area.fromText(lower);
}

Map<String, dynamic> asRow(Object? value) =>
    Map<String, dynamic>.from(value as Map);
