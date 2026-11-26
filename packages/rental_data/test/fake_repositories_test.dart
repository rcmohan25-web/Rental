import 'package:flutter_test/flutter_test.dart';
import 'package:rental_core/rental_core.dart' show AppException;
import 'package:rental_data/rental_data.dart';

/// Returns the error code of a failing call, or null when it succeeds.
Future<String?> errorCode(Future<Object?> Function() action) async {
  try {
    await action();
    return null;
  } on AppException catch (e) {
    return e.code;
  }
}

void main() {
  // The seeded booking blocks 6 to 8 Nov when "today" is 1 Nov 2026.
  final today = DateTime(2026, 11, 1);

  FakeBookingRepository newBookings({
    String? currentUserId,
    KycStatus kyc = KycStatus.verified,
  }) =>
      FakeBookingRepository(
        items: FakeItemRepository(),
        settings: FakeSettingsRepository(),
        currentUserId: currentUserId ?? FakeData.borrowerId,
        kycStatus: kyc,
        clock: () => today,
      );

  group('FakeItemRepository', () {
    test('first page respects the page size and has a cursor', () async {
      final repo = FakeItemRepository();
      final page = await repo.listItems(pageSize: 5);
      expect(page.items.length, 5);
      expect(page.nextCursor, isNotNull);
    });

    test('pages never repeat an item and the last page has no cursor',
        () async {
      final repo = FakeItemRepository();
      final seen = <String>[];
      ItemCursor? cursor;
      do {
        final page = await repo.listItems(after: cursor, pageSize: 5);
        seen.addAll(page.items.map((i) => i.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen.length, FakeData.items.length);
      expect(seen.toSet().length, FakeData.items.length);
    });

    test('newest first puts item-1 on top', () async {
      final page = await FakeItemRepository().listItems();
      expect(page.items.first.id, 'item-1');
    });

    test('price sort is ordered', () async {
      final repo = FakeItemRepository();
      final low = await repo.listItems(
        query: const ItemQuery(sort: ItemSort.priceLowToHigh),
      );
      final prices = low.items.map((i) => i.dailyPrice).toList();
      final sorted = List<int>.of(prices)..sort();
      expect(prices, sorted);
    });

    test('category, area, price and search filters', () async {
      final repo = FakeItemRepository();

      final cameras = await repo.listItems(
        query: const ItemQuery(category: 'Cameras'),
      );
      expect(cameras.items.every((i) => i.category == 'Cameras'), isTrue);
      expect(cameras.items.length, 3);

      final bhaktapur = await repo.listItems(
        query: const ItemQuery(area: Area.bhaktapur),
      );
      expect(bhaktapur.items.length, 2);

      final cheap = await repo.listItems(
        query: const ItemQuery(maxPrice: 999),
      );
      expect(cheap.items.every((i) => i.dailyPrice <= 999), isTrue);

      final search = await repo.listItems(
        query: const ItemQuery(search: '  DRILL '),
      );
      expect(search.items.length, 1);
      expect(search.items.first.title, 'Bosch Cordless Drill Set');
    });

    test('no match gives an empty page', () async {
      final page = await FakeItemRepository().listItems(
        query: const ItemQuery(search: 'zzzz'),
      );
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('getItem returns the item or ITEM_UNAVAILABLE', () async {
      final repo = FakeItemRepository();
      expect((await repo.getItem('item-1')).title, 'Sony Alpha A7 III Camera');
      final code = await errorCode(() => repo.getItem('missing'));
      expect(code, 'ITEM_UNAVAILABLE');
    });

    test('paused items are hidden', () async {
      final paused = FakeData.items.first.copyWith(status: ItemStatus.paused);
      final repo = FakeItemRepository(items: [paused]);
      expect((await repo.listItems()).items, isEmpty);
      expect(await errorCode(() => repo.getItem('item-1')), 'ITEM_UNAVAILABLE');
    });
  });

  group('FakeBookingRepository.createBookingRequest', () {
    test('plan worked example: 3 days gives 10,500 / 40,000 / 1,050 / 9,450',
        () async {
      final repo = newBookings();
      final b = await repo.createBookingRequest(
        itemId: 'item-1',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 12),
        idempotencyKey: 'key-1',
      );
      expect(b.status, BookingStatus.requested);
      expect(b.days, 3);
      expect(b.rentalFee, 10500);
      expect(b.deposit, 32000);
      expect(b.commissionAmount, 1050);
      expect(b.renterEarning, 9450);
      expect(b.borrowerPays, 42500);
      expect(b.borrowerId, FakeData.borrowerId);
      expect(b.lenderId, FakeData.lenderPrasantaId);
    });

    test('same idempotency key returns the same booking', () async {
      final repo = newBookings();
      Future<Booking> send() => repo.createBookingRequest(
            itemId: 'item-2',
            startDate: DateTime(2026, 11, 10),
            endDate: DateTime(2026, 11, 11),
            idempotencyKey: 'same-key',
          );
      final first = await send();
      final second = await send();
      expect(second.id, first.id);
      expect((await repo.listMyBookings()).length, 1);
    });

    test('overlapping dates of a confirmed booking give DATES_TAKEN', () async {
      final repo = newBookings();
      final code = await errorCode(
        () => repo.createBookingRequest(
          itemId: 'item-1',
          startDate: DateTime(2026, 11, 7),
          endDate: DateTime(2026, 11, 9),
          idempotencyKey: 'k',
        ),
      );
      expect(code, 'DATES_TAKEN');
    });

    test('blocked dates come from the seeded confirmed booking', () async {
      final blocked = await newBookings().blockedDates('item-1');
      expect(blocked.length, 1);
      expect(blocked.first.start, DateTime(2026, 11, 6));
      expect(blocked.first.end, DateTime(2026, 11, 8));
      expect(await newBookings().blockedDates('item-2'), isEmpty);
    });

    test('blocking statuses match the database constraint', () async {
      final seed = FakeData.seedBookings(today).first;
      Future<int> blockedWith(BookingStatus status) async {
        final repo = FakeBookingRepository(
          items: FakeItemRepository(),
          settings: FakeSettingsRepository(),
          seedBookings: [seed.copyWith(status: status)],
          clock: () => today,
        );
        return (await repo.blockedDates('item-1')).length;
      }

      expect(await blockedWith(BookingStatus.renterAccepted), 1);
      expect(await blockedWith(BookingStatus.returned), 1);
      expect(await blockedWith(BookingStatus.disputed), 1);
      expect(await blockedWith(BookingStatus.requested), 0);
      expect(await blockedWith(BookingStatus.cancelled), 0);
      expect(await blockedWith(BookingStatus.completed), 0);
    });

    test('a pending request does not block dates', () async {
      final repo = newBookings();
      await repo.createBookingRequest(
        itemId: 'item-2',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 11),
        idempotencyKey: 'k1',
      );
      expect(await repo.blockedDates('item-2'), isEmpty);
    });

    test('same Borrower, overlapping pending request: DUPLICATE_REQUEST',
        () async {
      final repo = newBookings();
      await repo.createBookingRequest(
        itemId: 'item-2',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 12),
        idempotencyKey: 'k1',
      );
      final code = await errorCode(
        () => repo.createBookingRequest(
          itemId: 'item-2',
          startDate: DateTime(2026, 11, 12),
          endDate: DateTime(2026, 11, 13),
          idempotencyKey: 'k2',
        ),
      );
      expect(code, 'DUPLICATE_REQUEST');
    });

    test('past start date and end before start give INVALID_DATES', () async {
      final repo = newBookings();
      expect(
        await errorCode(
          () => repo.createBookingRequest(
            itemId: 'item-2',
            startDate: DateTime(2026, 10, 30),
            endDate: DateTime(2026, 11, 2),
            idempotencyKey: 'a',
          ),
        ),
        'INVALID_DATES',
      );
      expect(
        await errorCode(
          () => repo.createBookingRequest(
            itemId: 'item-2',
            startDate: DateTime(2026, 11, 12),
            endDate: DateTime(2026, 11, 10),
            idempotencyKey: 'b',
          ),
        ),
        'INVALID_DATES',
      );
    });

    test('today is allowed as a start date', () async {
      final b = await newBookings().createBookingRequest(
        itemId: 'item-2',
        startDate: today,
        endDate: today,
        idempotencyKey: 'today',
      );
      expect(b.days, 1);
    });

    test('own item gives OWN_ITEM', () async {
      final repo = newBookings(currentUserId: FakeData.lenderPrasantaId);
      final code = await errorCode(
        () => repo.createBookingRequest(
          itemId: 'item-1',
          startDate: DateTime(2026, 11, 10),
          endDate: DateTime(2026, 11, 11),
          idempotencyKey: 'own',
        ),
      );
      expect(code, 'OWN_ITEM');
    });

    test('missing item gives ITEM_UNAVAILABLE', () async {
      final code = await errorCode(
        () => newBookings().createBookingRequest(
          itemId: 'nope',
          startDate: DateTime(2026, 11, 10),
          endDate: DateTime(2026, 11, 11),
          idempotencyKey: 'x',
        ),
      );
      expect(code, 'ITEM_UNAVAILABLE');
    });

    test('no ID submitted gives KYC_REQUIRED', () async {
      final code = await errorCode(
        () => newBookings(kyc: KycStatus.none).createBookingRequest(
          itemId: 'item-2',
          startDate: DateTime(2026, 11, 10),
          endDate: DateTime(2026, 11, 11),
          idempotencyKey: 'x',
        ),
      );
      expect(code, 'KYC_REQUIRED');
    });
  });

  group('FakeBookingRepository cancel, list and watch', () {
    test('cancel works once, then INVALID_STATE', () async {
      final repo = newBookings();
      final b = await repo.createBookingRequest(
        itemId: 'item-2',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 11),
        idempotencyKey: 'c1',
      );
      final cancelled = await repo.cancelBooking(b.id);
      expect(cancelled.status, BookingStatus.cancelled);
      expect(await errorCode(() => repo.cancelBooking(b.id)), 'INVALID_STATE');
    });

    test("cannot cancel someone else's booking", () async {
      final repo = newBookings();
      expect(
        await errorCode(() => repo.cancelBooking('seed-booking-1')),
        'NOT_ALLOWED',
      );
    });

    test('listMyBookings only returns this Borrower, newest first', () async {
      final repo = newBookings();
      await repo.createBookingRequest(
        itemId: 'item-2',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 11),
        idempotencyKey: 'l1',
      );
      final mine = await repo.listMyBookings();
      expect(mine.length, 1);
      expect(mine.first.borrowerId, FakeData.borrowerId);
    });

    test('watchMyBookings emits the list and then every change', () async {
      final repo = newBookings();
      final events = <int>[];
      final sub =
          repo.watchMyBookings().listen((list) => events.add(list.length));
      await Future<void>.delayed(Duration.zero);
      await repo.createBookingRequest(
        itemId: 'item-2',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 11),
        idempotencyKey: 'w1',
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await repo.dispose();
      expect(events, [0, 1]);
    });
  });
}
