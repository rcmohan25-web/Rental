import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_data/rental_data.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => RentalBackend.profiles(),
);

final kycRepositoryProvider = Provider<KycRepository>(
  (ref) => RentalBackend.kyc(),
);

/// The signed-in user's profile (includes kyc_status).
final myProfileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).getMyProfile(),
);

/// Status, rejection reason and dates of the user's ID submission.
final myKycStatusProvider = FutureProvider.autoDispose<KycStatusInfo>(
  (ref) => ref.watch(kycRepositoryProvider).getMyKycStatus(),
);
