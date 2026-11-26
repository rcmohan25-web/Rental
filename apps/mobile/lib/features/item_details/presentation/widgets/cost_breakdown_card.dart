import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Fee and deposit shown SEPARATELY, with the manual-payment honesty label.
/// All numbers come from [Money]; nothing is calculated in the widget.
class CostBreakdownCard extends StatelessWidget {
  const CostBreakdownCard({
    required this.breakdown,
    required this.dailyPrice,
    super.key,
  });

  final MoneyBreakdown breakdown;
  final int dailyPrice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dayWord = breakdown.days == 1 ? 'day' : 'days';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost breakdown', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            _Row(
              label:
                  '${Formatters.npr(dailyPrice)} x ${breakdown.days} $dayWord',
              value: Formatters.npr(breakdown.rentalFee),
              bold: false,
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Refundable deposit',
              value: Formatters.npr(breakdown.deposit),
              bold: false,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            _Row(
              label: 'Total to pay after approval',
              value: Formatters.npr(breakdown.borrowerPays),
              bold: true,
            ),
            const SizedBox(height: 12),
            const StatusChip(
              label: HonestyTexts.manualPayment,
              tone: StatusTone.info,
            ),
            const SizedBox(height: 8),
            const Text(
              'The deposit is returned when the item is back in good '
              'condition. Sending a request does not charge you.',
              style: TextStyle(color: BrandColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.bold});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontSize: bold ? 16 : 14,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text(value, style: style),
      ],
    );
  }
}
