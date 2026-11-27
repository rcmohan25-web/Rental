import 'package:equatable/equatable.dart';

/// One ID waiting for an admin. The photo URLs are short-lived signed URLs.
class PendingKyc extends Equatable {
  const PendingKyc({
    required this.userId,
    required this.displayName,
    required this.submittedAt,
    required this.idPhotoUrl,
    required this.facePhotoUrl,
  });

  final String userId;
  final String displayName;
  final DateTime submittedAt;
  final String idPhotoUrl;
  final String facePhotoUrl;

  @override
  List<Object?> get props => [
        userId,
        displayName,
        submittedAt,
        idPhotoUrl,
        facePhotoUrl,
      ];
}

/// Admin side of the ID check (RPC `admin_review_kyc`). "Verified" means
/// checked by an admin, nothing automatic.
abstract class AdminKycRepository {
  /// Oldest first.
  Future<List<PendingKyc>> listPending();

  /// A rejection needs a [reason] (REASON_REQUIRED otherwise).
  Future<void> review({
    required String userId,
    required bool approve,
    String? reason,
  });
}
