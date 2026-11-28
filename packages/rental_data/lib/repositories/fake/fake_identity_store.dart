import 'dart:async';

import 'package:rental_core/rental_core.dart' show AppException;

import '../../models/models.dart';

/// One in-memory account shared by the identity fakes (auth, profile, KYC and
/// admin KYC), so signing up, submitting an ID and approving it work end to end
/// without a database. Fake data only.
class FakeAccount {
  FakeAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
    this.area,
    this.role = UserRole.user,
    this.kyc = KycStatus.none,
    this.kycReason,
    this.submittedAt,
    this.reviewedAt,
  }) : createdAt = DateTime.now().toUtc();

  final String id;
  final String email;
  final String password;
  String fullName;
  String? phone;
  Area? area;
  UserRole role;
  KycStatus kyc;
  String? kycReason;
  DateTime? submittedAt;
  DateTime? reviewedAt;
  final DateTime createdAt;

  String get firstName {
    final trimmed = fullName.trim();
    return trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
  }

  Profile toProfile() => Profile(
        id: id,
        fullName: fullName,
        firstName: firstName,
        phone: phone,
        area: area,
        role: role,
        kycStatus: kyc,
        kycRejectReason: kyc == KycStatus.rejected ? kycReason : null,
        createdAt: createdAt,
      );
}

/// The "database" of the identity fakes.
class FakeIdentityStore {
  FakeIdentityStore({List<FakeAccount>? accounts, this.currentUserId})
      : accounts = accounts ?? [_defaultAdmin()];

  /// Id of the seeded admin account.
  static const String adminId = 'fake-admin';

  /// Seeded admin sign-in for the fakes: admin@sapati.test / admin12345.
  static FakeAccount _defaultAdmin() => FakeAccount(
        id: adminId,
        email: 'admin@sapati.test',
        password: 'admin12345',
        fullName: 'Sapati Admin',
        role: UserRole.admin,
        kyc: KycStatus.verified,
      );

  final List<FakeAccount> accounts;
  String? currentUserId;
  int _counter = 0;
  final StreamController<String?> _changes =
      StreamController<String?>.broadcast();

  Stream<String?> get changes => _changes.stream;

  String nextId() => 'fake-user-${++_counter}';

  void setCurrent(String? id) {
    currentUserId = id;
    if (!_changes.isClosed) _changes.add(id);
  }

  /// The signed-in account, or a NOT_AUTHENTICATED error.
  FakeAccount get me {
    final id = currentUserId;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    throw const AppException(
      'Please sign in to continue.',
      code: 'NOT_AUTHENTICATED',
    );
  }

  FakeAccount? byEmail(String email) {
    final wanted = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email == wanted) return account;
    }
    return null;
  }
}
