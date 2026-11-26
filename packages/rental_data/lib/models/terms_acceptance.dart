import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

/// A recorded tick of the "I have read and accept" box (planned table
/// `terms_acceptances`). Not a certified electronic signature
/// (see HonestyTexts.tickIsAcceptance).
class TermsAcceptance extends Equatable {
  const TermsAcceptance({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.role,
    required this.termsDocumentId,
    required this.version,
    required this.acceptedAt,
    required this.appVersion,
  });

  factory TermsAcceptance.fromJson(Map<String, dynamic> json) =>
      TermsAcceptance(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
        termsDocumentId: json['terms_document_id'] as String,
        version: json['version'] as String,
        acceptedAt: parseTimestamp(json['accepted_at']),
        appVersion: json['app_version'] as String,
      );

  final String id;
  final String bookingId;
  final String userId;

  /// 'renter' or 'borrower'.
  final String role;
  final String termsDocumentId;

  /// The accepted version text (terms versions are text in the schema).
  final String version;

  /// Set by the server, never by the app.
  final DateTime acceptedAt;
  final String appVersion;

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'user_id': userId,
        'role': role,
        'terms_document_id': termsDocumentId,
        'version': version,
        'accepted_at': formatTimestamp(acceptedAt),
        'app_version': appVersion,
      };

  @override
  List<Object?> get props => [
        id,
        bookingId,
        userId,
        role,
        termsDocumentId,
        version,
        acceptedAt,
        appVersion,
      ];
}
