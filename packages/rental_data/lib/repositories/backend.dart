import 'fake/fakes.dart';
import 'admin_kyc_repository.dart';
import 'auth_repository.dart';
import 'item_repository.dart';
import 'kyc_repository.dart';
import 'profile_repository.dart';
import 'settings_repository.dart';

/// The one seam between the apps and the data layer. Apps never import
/// Supabase: they call these factories (from a Riverpod provider) and get
/// either the in-memory fakes or the real repositories.
///
/// STUB (Build 0.4, Mohan): always returns fakes so the UI can be built and run
/// without a database. Srijan replaces this file with the Supabase-aware
/// version in the same build (`isLive` becomes true after `initialize`).
abstract final class RentalBackend {
  static const Duration _fakeLatency = Duration(milliseconds: 300);
  static final FakeIdentityStore _identity = FakeIdentityStore();

  /// True when the Supabase repositories are in use.
  static bool get isLive => false;

  /// Call once from main() when the build has SUPABASE_URL and the anon key.
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {}

  static AuthRepository auth() =>
      FakeAuthRepository(store: _identity, latency: _fakeLatency);

  static ProfileRepository profiles() =>
      FakeProfileRepository(store: _identity, latency: _fakeLatency);

  static KycRepository kyc() =>
      FakeKycRepository(store: _identity, latency: _fakeLatency);

  static AdminKycRepository adminKyc() =>
      FakeAdminKycRepository(store: _identity, latency: _fakeLatency);

  static ItemRepository items() => FakeItemRepository(latency: _fakeLatency);

  static SettingsRepository settings() =>
      FakeSettingsRepository(latency: _fakeLatency);
}
