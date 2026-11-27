import 'package:rental_core/rental_core.dart';

const String _generic = 'Something went wrong. Please try again.';

/// Friendly text for the error codes of docs/api-contract.md section 11 that
/// the listing screens can meet.
const Map<String, String> _messages = {
  'KYC_REQUIRED': 'Please submit your ID before you publish a listing.',
  'ACCOUNT_RESTRICTED': 'Your account is restricted. Please contact support.',
  'INVALID_VALUE':
      'Please check the form: the declared value must reach the minimum set '
      'by Sapati, and a published listing needs a category, a condition '
      'and 1 to 5 photos.',
  'SETTING_UNAVAILABLE':
      'The platform rules are not available right now. Please try later.',
  'EVIDENCE_MISSING': 'A photo is missing. Please add the photos again.',
  'ACTIVE_BOOKINGS_EXIST':
      'This item has an accepted booking, so it cannot be deleted yet.',
  'NOT_ALLOWED': 'You cannot change this item.',
  'NOT_AUTHENTICATED': 'Please sign in to continue.',
  'IMAGE_TOO_LARGE': 'This photo is too large. Please choose a smaller one.',
  'UPLOAD_FAILED': 'The photo could not be uploaded. Please try again.',
  'NETWORK': 'No connection. Check your internet and try again.',
};

String friendlyListingError(Object error) {
  if (error is AppException) {
    final code = error.code;
    if (code != null && _messages.containsKey(code)) return _messages[code]!;
  }
  return _generic;
}

/// Whole NPR from text such as "160,000". Null when it is not a whole number.
int? parseNpr(String text) => int.tryParse(text.replaceAll(',', '').trim());
