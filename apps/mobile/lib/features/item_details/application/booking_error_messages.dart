import 'package:rental_core/rental_core.dart';

const String _generic = 'Something went wrong. Please try again.';

/// Friendly text for each error code in docs/api-contract.md section 7.
/// (Later this can move to rental_core/errors, which Mohan owns.)
const Map<String, String> _messages = {
  'NOT_AUTHENTICATED': 'Please sign in to continue.',
  'NOT_ALLOWED': 'You cannot do this on this booking.',
  'ACCOUNT_RESTRICTED': 'Your account is restricted. Please contact support.',
  'KYC_REQUIRED': 'Please submit your ID before sending a request.',
  'ITEM_UNAVAILABLE': 'This item is no longer available.',
  'OWN_ITEM': 'You cannot rent your own item.',
  'INVALID_DATES': 'Please choose dates that start today or later.',
  'DATES_TAKEN': 'Those dates are already booked. Please choose other dates.',
  'DUPLICATE_REQUEST':
      'You already have a pending request for these dates on this item.',
  'INVALID_STATE': 'This booking has already changed. Please refresh.',
  'SETTING_UNAVAILABLE':
      'The platform rules are not available right now. Please try later.',
  'TERMS_UNAVAILABLE':
      'The terms are not available right now. Please try later.',
};

/// Turns any error into text that is safe to show to the user.
String friendlyBookingError(Object error) {
  if (error is AppException) {
    final code = error.code;
    if (code != null && _messages.containsKey(code)) return _messages[code]!;
  }
  return _generic;
}
