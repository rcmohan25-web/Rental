import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../../shared/id_gate.dart';
import '../../explore/application/catalog_providers.dart';
import '../application/booking_error_messages.dart';
import '../application/idempotency.dart';
import '../application/item_details_provider.dart';
import 'widgets/cost_breakdown_card.dart';
import 'widgets/photo_carousel.dart';

/// One item: photos, price, deposit (always separate), date picker that
/// refuses taken dates, cost breakdown and "Send rental request".
/// A request is NOT a booking: the Renter must accept first. Owner: Smaran.
class ItemDetailsScreen extends ConsumerStatefulWidget {
  const ItemDetailsScreen({this.itemId, super.key});

  /// Null when opened from the skeleton list without an item.
  final String? itemId;

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  DateTimeRange? _range;
  String? _rangeError;
  String? _sendError;
  String? _idempotencyKey;
  bool _sending = false;
  Booking? _sent;

  Future<void> _pickDates(ItemDetailsData data) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(first.year + 1, first.month, first.day),
      initialDateRange: _range,
      helpText: 'Select rental dates',
    );
    if (picked == null || !mounted) return;
    final clash = data.blockedDates.any(
      (r) => r.overlaps(picked.start, picked.end),
    );
    setState(() {
      _range = clash ? null : picked;
      _rangeError = clash
          ? 'Some of those dates are already booked. Please choose other dates.'
          : null;
      // New dates mean a new request, so a new key.
      _idempotencyKey = null;
      _sent = null;
      _sendError = null;
    });
  }

  Future<void> _send(Item item) async {
    final range = _range;
    if (range == null || _sending) return;
    // The ID gate: an ID must be submitted before the first request.
    if (!await ensureIdSubmitted(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    // One key per request attempt; a retry reuses it, so it cannot double up.
    final key = _idempotencyKey ??= generateIdempotencyKey();
    try {
      final booking =
          await ref.read(bookingRepositoryProvider).createBookingRequest(
                itemId: item.id,
                startDate: range.start,
                endDate: range.end,
                idempotencyKey: key,
              );
      if (!mounted) return;
      setState(() {
        _sent = booking;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendError = friendlyBookingError(e);
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemId = widget.itemId;
    if (itemId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item details')),
        body: EmptyState(
          title: 'No item selected',
          message: 'Choose an item from Explore.',
          icon: Icons.search,
          action: SecondaryButton(
            label: 'Go to Explore',
            onPressed: () => context.go('/explore'),
          ),
        ),
      );
    }

    final details = ref.watch(itemDetailsProvider(itemId));
    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: details.when(
        loading: () => const LoadingView(message: 'Loading item'),
        error: (error, stack) => ErrorState(
          onRetry: () => ref.invalidate(itemDetailsProvider(itemId)),
        ),
        data: (data) {
          final item = data.item;
          final settings = data.settings;
          if (item == null || settings == null) {
            return ErrorState(
              message: data.errorMessage ?? 'This item is not available.',
              onRetry: () => ref.invalidate(itemDetailsProvider(itemId)),
            );
          }
          return _buildItem(context, item, data, settings);
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    Item item,
    ItemDetailsData data,
    AppSettings settings,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final minDeposit = settings.minDepositAmount ?? 0;
    final deposit = Money.deposit(
      item.declaredValue,
      settings.depositRateBps,
      minDepositAmount: minDeposit,
    );
    final range = _range;
    final requestsEnabled = ref.watch(bookingRequestsEnabledProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        PhotoCarousel(photoUrls: item.photoUrls),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${Formatters.npr(item.dailyPrice)} / day',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Refundable deposit: ${Formatters.npr(deposit)}',
                style: const TextStyle(color: BrandColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(item.pickupArea)),
                  Chip(label: Text(item.category)),
                  Chip(label: Text('Condition: ${item.condition}')),
                ],
              ),
              const SizedBox(height: 16),
              Text('About this item', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(item.description),
              if (item.rules != null) ...[
                const SizedBox(height: 16),
                Text('Rules', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(item.rules!),
              ],
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(item.lenderFirstName ?? 'Renter'),
                  subtitle: const Text(
                    'Contact details and the exact pickup address are shared '
                    'after your payment is verified.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Choose your dates', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.blockedDates.isNotEmpty) ...[
                Text(
                  'Already booked: ${data.blockedDates.map((r) => Formatters.dateRange(r.start, r.end)).join(', ')}',
                  style: const TextStyle(
                    color: BrandColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SecondaryButton(
                label: range == null
                    ? 'Select rental dates'
                    : Formatters.dateRange(range.start, range.end),
                icon: Icons.calendar_month,
                onPressed: _sent == null ? () => _pickDates(data) : null,
              ),
              if (_rangeError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _rangeError!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
              ],
              if (range != null) ...[
                const SizedBox(height: 16),
                CostBreakdownCard(
                  breakdown: Money.breakdown(
                    start: range.start,
                    end: range.end,
                    dailyPrice: item.dailyPrice,
                    declaredValue: item.declaredValue,
                    depositRateBps: settings.depositRateBps,
                    commissionRateBps: settings.commissionRateBps,
                    minDepositAmount: minDeposit,
                  ),
                  dailyPrice: item.dailyPrice,
                ),
                const SizedBox(height: 16),
                if (!requestsEnabled)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Rental requests open in the next build. This item '
                        'and its price are live, but a request cannot be '
                        'sent yet.',
                      ),
                    ),
                  )
                else if (_sent == null)
                  PrimaryButton(
                    label: 'Send rental request',
                    loading: _sending,
                    onPressed: () => _send(item),
                  ),
                if (_sendError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sendError!,
                    style: const TextStyle(color: BrandColors.danger),
                  ),
                ],
              ],
              if (_sent != null) ...[
                const SizedBox(height: 16),
                _SentCard(booking: _sent!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown after a request is created. Makes the key rule clear: a request is
/// not a confirmed booking.
class _SentCard extends StatelessWidget {
  const _SentCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusChip(label: 'Requested', tone: StatusTone.warning),
            const SizedBox(height: 8),
            Text(
              'Request sent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.dateRange(booking.startDate, booking.endDate)} '
              '(${booking.days} days). The Renter must accept before anything '
              'is confirmed. Nothing has been charged.',
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'View my bookings',
              onPressed: () => context.push('/bookings'),
            ),
          ],
        ),
      ),
    );
  }
}
