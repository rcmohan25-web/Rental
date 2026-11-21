/// Simple error type shown to users. Repositories map server errors to this.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  /// Safe to show in the UI.
  final String message;

  /// Machine-readable code, for example `kyc_required` or `dates_unavailable`.
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}
