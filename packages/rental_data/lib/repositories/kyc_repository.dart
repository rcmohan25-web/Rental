import 'package:equatable/equatable.dart';

import '../models/models.dart';
import 'image_upload.dart';

/// Result of `get_my_kyc_status`. Never contains file paths.
class KycStatusInfo extends Equatable {
  const KycStatusInfo({
    required this.status,
    this.reason,
    this.submittedAt,
    this.reviewedAt,
  });

  final KycStatus status;

  /// Only set when [status] is rejected.
  final String? reason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  @override
  List<Object?> get props => [status, reason, submittedAt, reviewedAt];
}

/// The user's own ID submission (RPCs `submit_kyc` and `get_my_kyc_status`).
abstract class KycRepository {
  Future<KycStatusInfo> getMyKycStatus();

  /// Uploads both photos to the private `kyc` bucket under the user's own
  /// folder, then calls `submit_kyc`. Throws AppException with INVALID_STATE
  /// when a submission is already pending or verified.
  Future<KycStatusInfo> submitKyc({
    required ImageUpload idPhoto,
    required ImageUpload facePhoto,
  });
}
