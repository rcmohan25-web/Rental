import 'package:flutter_test/flutter_test.dart';
import 'package:rental_data/rental_data.dart';

void main() {
  final created = DateTime.utc(2026, 11, 3, 4, 30);

  group('enums', () {
    test('every wire value round-trips', () {
      for (final v in UserRole.values) {
        expect(UserRole.fromWire(v.wire), v);
      }
      for (final v in AccountStatus.values) {
        expect(AccountStatus.fromWire(v.wire), v);
      }
      for (final v in KycStatus.values) {
        expect(KycStatus.fromWire(v.wire), v);
      }
      for (final v in Area.values) {
        expect(Area.fromWire(v.wire), v);
      }
      for (final v in ItemStatus.values) {
        expect(ItemStatus.fromWire(v.wire), v);
      }
      for (final v in TermsStatus.values) {
        expect(TermsStatus.fromWire(v.wire), v);
      }
      for (final v in TermsAudience.values) {
        expect(TermsAudience.fromWire(v.wire), v);
      }
      for (final v in BookingStatus.values) {
        expect(BookingStatus.fromWire(v.wire), v);
      }
      for (final v in PaymentStatus.values) {
        expect(PaymentStatus.fromWire(v.wire), v);
      }
      for (final v in LedgerEntryType.values) {
        expect(LedgerEntryType.fromWire(v.wire), v);
      }
      for (final v in LedgerStatus.values) {
        expect(LedgerStatus.fromWire(v.wire), v);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(() => BookingStatus.fromWire('nope'), throwsFormatException);
    });

    test('booking status wire names match the contract', () {
      expect(BookingStatus.renterAccepted.wire, 'renter_accepted');
      expect(BookingStatus.awaitingPayment.wire, 'awaiting_payment');
      expect(BookingStatus.paymentSubmitted.wire, 'payment_submitted');
      expect(BookingStatus.paymentVerified.wire, 'payment_verified');
      expect(BookingStatus.handedOver.wire, 'handed_over');
    });

    test('blocksDates matches the prevent_double_booking constraint', () {
      final blocking = BookingStatus.values.where((s) => s.blocksDates);
      expect(blocking.toSet(), {
        BookingStatus.renterAccepted,
        BookingStatus.awaitingPayment,
        BookingStatus.paymentSubmitted,
        BookingStatus.paymentVerified,
        BookingStatus.handedOver,
        BookingStatus.returned,
        BookingStatus.disputed,
      });
    });

    test('borrowerCanCancel is true before payment only', () {
      final cancellable = BookingStatus.values.where(
        (s) => s.borrowerCanCancel,
      );
      expect(cancellable.toSet(), {
        BookingStatus.requested,
        BookingStatus.renterAccepted,
        BookingStatus.awaitingPayment,
      });
    });

    test('finished statuses', () {
      expect(BookingStatus.completed.isFinished, isTrue);
      expect(BookingStatus.declined.isFinished, isTrue);
      expect(BookingStatus.returned.isFinished, isFalse);
      expect(BookingStatus.disputed.isFinished, isFalse);
    });

    test('Area.fromText finds the valley area in free text', () {
      expect(Area.fromText('Jawalakhel Chowk, Lalitpur'), Area.lalitpur);
      expect(Area.fromText('THAMEL, kathmandu'), Area.kathmandu);
      expect(Area.fromText('Bhaktapur Durbar Square'), Area.bhaktapur);
      expect(Area.fromText('Pokhara'), isNull);
    });
  });

  group('DateRange', () {
    test('overlap is inclusive on both ends', () {
      final r = DateRange(DateTime(2026, 11, 6), DateTime(2026, 11, 8));
      expect(r.overlaps(DateTime(2026, 11, 8), DateTime(2026, 11, 9)), isTrue);
      expect(r.overlaps(DateTime(2026, 11, 4), DateTime(2026, 11, 6)), isTrue);
      expect(r.overlaps(DateTime(2026, 11, 7), DateTime(2026, 11, 7)), isTrue);
      final later = r.overlaps(DateTime(2026, 11, 9), DateTime(2026, 11, 10));
      expect(later, isFalse);
      expect(r.overlaps(DateTime(2026, 11, 1), DateTime(2026, 11, 5)), isFalse);
    });

    test('json round trip', () {
      final r = DateRange(DateTime(2026, 11, 6), DateTime(2026, 11, 8));
      final json = r.toJson();
      expect(json, {'start_date': '2026-11-06', 'end_date': '2026-11-08'});
      expect(DateRange.fromJson(r.toJson()), r);
    });
  });

  group('Profile', () {
    test('committed schema row (display_name only) is readable', () {
      final p = Profile.fromJson({
        'id': 'u1',
        'display_name': 'Aayush Shrestha',
        'created_at': '2026-11-03T04:30:00Z',
        'updated_at': '2026-11-03T04:30:00Z',
      });
      expect(p.fullName, 'Aayush Shrestha');
      expect(p.firstName, 'Aayush');
      expect(p.role, UserRole.user);
      expect(p.kycStatus, KycStatus.none);
      expect(p.area, isNull);
      expect(p.isAdmin, isFalse);
    });

    test('json round trip with the planned columns', () {
      final p = Profile(
        id: 'u1',
        fullName: 'Aayush Shrestha',
        firstName: 'Aayush',
        phone: '9800000000',
        area: Area.lalitpur,
        role: UserRole.user,
        accountStatus: AccountStatus.active,
        kycStatus: KycStatus.pending,
        createdAt: created,
      );
      expect(Profile.fromJson(p.toJson()), p);
      expect(p.isActive, isTrue);
    });
  });

  group('Item', () {
    final row = <String, dynamic>{
      'id': 'i1',
      'lender_id': 'u2',
      'title': 'Sony Alpha A7 III Camera',
      'description': null,
      'daily_rate': 3500.00,
      'declared_value': 160000.00,
      'pickup_area': 'Jawalakhel Chowk, Lalitpur',
      'status': 'active',
      'created_at': '2026-11-03T04:30:00Z',
      'updated_at': '2026-11-03T04:30:00Z',
    };

    test('committed schema row is readable (numeric money, free-text area)',
        () {
      final item = Item.fromJson(row);
      expect(item.dailyPrice, 3500);
      expect(item.declaredValue, 160000);
      expect(item.pickupArea, 'Jawalakhel Chowk, Lalitpur');
      expect(item.area, Area.lalitpur);
      expect(item.isActive, isTrue);
      expect(item.description, '');
      expect(item.photoUrls, isEmpty);
    });

    test('draft and paused items are not active', () {
      expect(Item.fromJson({...row, 'status': 'draft'}).isActive, isFalse);
      expect(Item.fromJson({...row, 'status': 'paused'}).isActive, isFalse);
    });

    test('money with paise is refused', () {
      expect(
        () => Item.fromJson({...row, 'daily_rate': 3500.5}),
        throwsFormatException,
      );
    });

    test('null declared value reads as 0 (not declared yet)', () {
      expect(Item.fromJson({...row, 'declared_value': null}).declaredValue, 0);
    });

    test('json round trip and cover photo', () {
      final item = FakeData.items.first;
      final back = Item.fromJson({
        ...item.toJson(),
        'lender_first_name': item.lenderFirstName,
      });
      expect(back, item);
      expect(item.coverPhoto, item.photoUrls.first);
    });

    test('toJson uses the contract column names, no joined name', () {
      final json = FakeData.items.first.toJson();
      expect(json.containsKey('daily_rate'), isTrue);
      expect(json.containsKey('pickup_area'), isTrue);
      expect(json.containsKey('status'), isTrue);
      expect(json.containsKey('lender_first_name'), isFalse);
    });
  });

  group('Booking', () {
    test('json round trip, borrowerPays and copyWith', () {
      final b = FakeData.seedBookings(DateTime(2026, 11, 1)).first;
      expect(Booking.fromJson(b.toJson()), b);
      expect(b.borrowerPays, 42500);
      final cancelled = b.copyWith(status: BookingStatus.cancelled);
      expect(cancelled.status, BookingStatus.cancelled);
      expect(cancelled.id, b.id);
    });

    test('rates travel as database fractions and come back as basis points',
        () {
      final b = FakeData.seedBookings(DateTime(2026, 11, 1)).first;
      final json = b.toJson();
      expect(json['commission_rate'], 0.1);
      expect(json['deposit_rate'], 0.2);
      final back = Booking.fromJson(json);
      expect(back.commissionRateBps, 1000);
      expect(back.depositRateBps, 2000);
    });

    test('terms_version_ids is a uuid array, as in the committed schema', () {
      final b = FakeData.seedBookings(DateTime(2026, 11, 1)).first;
      expect(b.toJson()['terms_version_ids'], isNotEmpty);
      expect(Booking.fromJson(b.toJson()).termsVersionIds.length, 3);
    });

    test('missing optional columns use safe defaults', () {
      final json = FakeData.seedBookings(DateTime(2026, 11, 1)).first.toJson()
        ..remove('is_overdue')
        ..remove('is_escalated')
        ..remove('has_damage_report')
        ..remove('terms_version_ids')
        ..remove('late_fee_multiplier')
        ..remove('return_grace_hours')
        ..remove('idempotency_key');
      final b = Booking.fromJson(json);
      expect(b.isOverdue, isFalse);
      expect(b.isEscalated, isFalse);
      expect(b.hasDamageReport, isFalse);
      expect(b.termsVersionIds, isEmpty);
      expect(b.lateFeeMultiplierX100, isNull);
      expect(b.idempotencyKey, isNull);
    });
  });

  group('LedgerEntry', () {
    test('json round trip', () {
      final e = LedgerEntry(
        id: 'l1',
        bookingId: 'b1',
        userId: 'u1',
        entryType: LedgerEntryType.renterEarning,
        amount: 9450,
        status: LedgerStatus.due,
        createdAt: created,
        paidAt: created,
        paidReference: 'ESEWA-123',
      );
      expect(LedgerEntry.fromJson(e.toJson()), e);
    });
  });

  group('Terms', () {
    test('committed schema row (title, text version, content, status)', () {
      final t = TermsDocument.fromJson({
        'id': 't1',
        'title': 'Borrower terms',
        'version': 'v1',
        'content': 'Prototype terms, not legal advice.',
        'status': 'published',
        'created_at': '2026-11-03T04:30:00Z',
        'published_at': '2026-11-03T05:00:00Z',
      });
      expect(t.body, 'Prototype terms, not legal advice.');
      expect(t.version, 'v1');
      expect(t.isActive, isTrue);
      expect(t.audience, isNull);
    });

    test('TermsDocument json round trip', () {
      final t = TermsDocument(
        id: 't1',
        title: 'Borrower terms',
        version: 'v2',
        body: 'Prototype terms, not legal advice.',
        status: TermsStatus.draft,
        audience: TermsAudience.borrower,
        createdAt: created,
      );
      expect(TermsDocument.fromJson(t.toJson()), t);
      expect(t.isActive, isFalse);
    });

    test('TermsAcceptance json round trip', () {
      final a = TermsAcceptance(
        id: 'a1',
        bookingId: 'b1',
        userId: 'u1',
        role: 'borrower',
        termsDocumentId: 't1',
        version: 'v2',
        acceptedAt: created,
        appVersion: '0.1.0+1',
      );
      expect(TermsAcceptance.fromJson(a.toJson()), a);
    });
  });

  group('AppSettings', () {
    final rows = <Map<String, dynamic>>[
      {'key': 'commission_rate', 'value': 0.1},
      {'key': 'deposit_rate', 'value': 0.2},
      {'key': 'late_fee_multiplier', 'value': 1.5},
      {'key': 'return_grace_hours', 'value': 24},
      {'key': 'legal_action_period_days', 'value': 14},
      {'key': 'request_expiry_hours', 'value': 48},
      {'key': 'min_declared_value', 'value': 2000},
      {'key': 'auto_approve_orders', 'value': true},
    ];

    test('reads the app_settings rows with the contract key names', () {
      final s = AppSettings.fromRows(rows);
      expect(s.commissionRateBps, 1000);
      expect(s.depositRateBps, 2000);
      expect(s.lateFeeMultiplierX100, 150);
      expect(s.returnGraceHours, 24);
      expect(s.minDeclaredValue, 2000);
      expect(s.autoApproveOrders, isTrue);
    });

    test('toKeyValues gives the same pairs back', () {
      final s = AppSettings.fromRows(rows);
      expect(AppSettings.fromKeyValues(s.toKeyValues()), s);
      expect(s.toKeyValues()['commission_rate'], 0.1);
      expect(s.toKeyValues()['late_fee_multiplier'], 1.5);
    });

    test('a missing key is an error, never a silent 0', () {
      final missing = rows.where((r) => r['key'] != 'deposit_rate');
      expect(() => AppSettings.fromRows(missing), throwsFormatException);
    });

    test('a malformed value is an error', () {
      final bad = [
        for (final r in rows)
          if (r['key'] == 'return_grace_hours')
            {'key': 'return_grace_hours', 'value': 'soon'}
          else
            r,
      ];
      expect(() => AppSettings.fromRows(bad), throwsFormatException);
    });
  });
}
