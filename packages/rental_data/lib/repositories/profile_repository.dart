import '../models/models.dart';

/// The signed-in user's own profile. Role, account status and KYC status are
/// read-only for the user (changed only by admin RPCs).
abstract class ProfileRepository {
  /// `profiles` joined with the owner-only `profile_private` row.
  Future<Profile> getMyProfile();

  /// Writes the display name (profiles) and phone and area (profile_private).
  Future<Profile> updateMyProfile({
    required String fullName,
    String? phone,
    Area? area,
  });
}
