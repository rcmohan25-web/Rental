/// App-wide constants. Values come from the business notes, never hard-code
/// commission or deposit rates here (they live in the app_settings table).
abstract final class AppConstants {
  static const String appName = 'Rental';
  static const String adminTitle = 'Rental Admin';
  static const String companyName = 'Sapati';
  static const String companyDomain = 'sapati.com';
  static const String supportEmail = 'support@sapati.com';
  static const String androidPackageId = 'com.sapati.rental';

  /// Dates are stored as date-only and interpreted in this time zone.
  static const String timeZone = 'Asia/Kathmandu';

  static const List<String> areas = ['Kathmandu', 'Lalitpur', 'Bhaktapur'];

  static const int maxListingPhotos = 5;
  static const int maxUploadBytes = 5 * 1024 * 1024;
  static const int targetImageBytes = 300 * 1024;
  static const int targetImageLongSide = 1080;
}
