import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_kyc_repository.dart';
import 'auth_repository.dart';
import 'fake/fakes.dart';
import 'item_repository.dart';
import 'kyc_repository.dart';
import 'listing_repository.dart';
import 'profile_repository.dart';
import 'settings_repository.dart';
import 'supabase/supabase_repositories.dart';

/// The one seam between the apps and the data layer. Apps never import
/// Supabase: they call these factories (from a Riverpod provider) and get the
/// Supabase repositories after [initialize], or the in-memory fakes before it
/// (no keys: the app still runs offline).
///
/// Owner: Srijan. Bookings stay on the fake until Phase 2 (their RPCs are not
/// all implemented yet), so there is no `bookings()` here: the booking provider
/// in `catalog_providers.dart` keeps building the fake.
abstract final class RentalBackend {
  static const Duration _fakeLatency = Duration(milliseconds: 300);
  static final FakeIdentityStore _identity = FakeIdentityStore();
  static final FakeListingRepository _fakeListings = FakeListingRepository(
    latency: _fakeLatency,
  );

  static SupabaseClient? _client;

  /// True when the Supabase repositories are in use.
  static bool get isLive => _client != null;

  /// Call once from main() when the build has SUPABASE_URL and the anon key.
  /// Only the anon (publishable) key is ever used in the apps.
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, publishableKey: anonKey);
    _client = Supabase.instance.client;
  }

  static AuthRepository auth() {
    final client = _client;
    return client == null
        ? FakeAuthRepository(store: _identity, latency: _fakeLatency)
        : SupabaseAuthRepository(client);
  }

  static ProfileRepository profiles() {
    final client = _client;
    return client == null
        ? FakeProfileRepository(store: _identity, latency: _fakeLatency)
        : SupabaseProfileRepository(client);
  }

  static KycRepository kyc() {
    final client = _client;
    return client == null
        ? FakeKycRepository(store: _identity, latency: _fakeLatency)
        : SupabaseKycRepository(client);
  }

  static AdminKycRepository adminKyc() {
    final client = _client;
    return client == null
        ? FakeAdminKycRepository(store: _identity, latency: _fakeLatency)
        : SupabaseAdminKycRepository(client);
  }

  static ItemRepository items() {
    final client = _client;
    return client == null
        ? FakeItemRepository(latency: _fakeLatency)
        : SupabaseItemRepository(client);
  }

  static SettingsRepository settings() {
    final client = _client;
    return client == null
        ? FakeSettingsRepository(latency: _fakeLatency)
        : SupabaseSettingsRepository(client);
  }

  static ListingRepository listings() {
    final client = _client;
    return client == null ? _fakeListings : SupabaseListingRepository(client);
  }
}
