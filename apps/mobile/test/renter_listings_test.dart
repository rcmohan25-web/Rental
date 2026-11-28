import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental/features/renter_listings/application/listing_error_messages.dart';
import 'package:rental/features/renter_listings/application/listing_providers.dart';
import 'package:rental/features/renter_listings/presentation/renter_listings_screen.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

void main() {
  test('error codes become friendly text, unknown ones generic', () {
    expect(
      friendlyListingError(const AppException('x', code: 'KYC_REQUIRED')),
      'Please submit your ID before you publish a listing.',
    );
    expect(
      friendlyListingError(
        const AppException('x', code: 'ACTIVE_BOOKINGS_EXIST'),
      ),
      contains('accepted booking'),
    );
    expect(
      friendlyListingError(StateError('boom')),
      'Something went wrong. Please try again.',
    );
  });

  test('parseNpr reads whole NPR only', () {
    expect(parseNpr('160,000'), 160000);
    expect(parseNpr(' 3500 '), 3500);
    expect(parseNpr('3500.5'), isNull);
    expect(parseNpr('abc'), isNull);
  });

  testWidgets('the list shows an empty state, then the new listing', (
    tester,
  ) async {
    final repo = FakeListingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [listingRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RenterListingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No listings yet'), findsOneWidget);
    expect(find.text('Add listing'), findsOneWidget);

    await tester.runAsync(
      () => repo.createListing(
        const ListingInput(
          title: 'Bosch Drill',
          description: '',
          category: 'Tools',
          condition: 'Good',
          declaredValue: 15000,
          dailyPrice: 500,
          pickupArea: 'Kupondole, Lalitpur',
          exactAddress: 'Kupondole 3',
          photos: [
            ListingPhoto.stored(
              path: 'u/p.jpg',
              url: 'https://example.test/p.jpg',
            ),
          ],
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RenterListingsScreen)),
    );
    container.invalidate(myItemsProvider);
    await tester.pumpAndSettle();

    expect(find.text('Bosch Drill'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
