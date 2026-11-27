import 'package:flutter_test/flutter_test.dart';
import 'package:rental/features/auth/application/auth_error_messages.dart';
import 'package:rental/features/auth/application/auth_providers.dart';
import 'package:rental_core/rental_core.dart';

void main() {
  group('mobileRedirect', () {
    test('signed out users are sent to the welcome screen', () {
      expect(mobileRedirect(userId: null, location: '/explore'), '/welcome');
      expect(mobileRedirect(userId: null, location: '/profile'), '/welcome');
    });

    test('signed out users may see the auth screens', () {
      for (final path in ['/splash', '/welcome', '/login', '/sign-up']) {
        expect(mobileRedirect(userId: null, location: path), isNull);
      }
    });

    test('the ID step needs a session', () {
      expect(mobileRedirect(userId: null, location: '/sign-up/id'), '/welcome');
      expect(mobileRedirect(userId: 'u1', location: '/sign-up/id'), isNull);
    });

    test('signed in users skip splash, welcome and login', () {
      for (final path in ['/splash', '/welcome', '/login']) {
        expect(mobileRedirect(userId: 'u1', location: path), '/explore');
      }
    });

    test('sign-up is not skipped, so the optional ID step still shows', () {
      expect(mobileRedirect(userId: 'u1', location: '/sign-up'), isNull);
    });
  });

  group('auth messages and validators', () {
    test('known codes get friendly text, unknown ones a generic text', () {
      expect(
        friendlyAuthError(const AppException('x', code: 'INVALID_CREDENTIALS')),
        'Wrong e-mail or password.',
      );
      expect(
        friendlyAuthError(StateError('boom')),
        'Something went wrong. Please try again.',
      );
    });

    test('e-mail and password rules', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validateEmail(' a@b.co '), isNull);
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword('longenough'), isNull);
    });
  });
}
