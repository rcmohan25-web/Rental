import '../../models/models.dart';
import '../profile_repository.dart';
import 'fake_identity_store.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    FakeIdentityStore? store,
    this.latency = Duration.zero,
  }) : store = store ?? FakeIdentityStore();

  final FakeIdentityStore store;
  final Duration latency;

  @override
  Future<Profile> getMyProfile() async {
    await Future<void>.delayed(latency);
    return store.me.toProfile();
  }

  @override
  Future<Profile> updateMyProfile({
    required String fullName,
    String? phone,
    Area? area,
  }) async {
    await Future<void>.delayed(latency);
    final me = store.me;
    me.fullName = fullName.trim();
    me.phone = (phone == null || phone.trim().isEmpty) ? null : phone.trim();
    me.area = area;
    return me.toProfile();
  }
}
