import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

/// One choice in the price filter.
class _PriceOption {
  const _PriceOption(this.label, this.min, this.max);

  final String label;
  final int? min;
  final int? max;
}

const List<_PriceOption> _priceOptions = [
  _PriceOption('Any price', null, null),
  _PriceOption('Under NPR 1,000', null, 999),
  _PriceOption('NPR 1,000 to 3,000', 1000, 3000),
  _PriceOption('Over NPR 3,000', 3001, null),
];

String _sortLabel(ItemSort sort) => switch (sort) {
      ItemSort.newest => 'Newest',
      ItemSort.priceLowToHigh => 'Price: low to high',
      ItemSort.priceHighToLow => 'Price: high to low',
    };

/// The values chosen in the sheet.
class FilterChoice {
  const FilterChoice({
    required this.area,
    required this.minPrice,
    required this.maxPrice,
    required this.sort,
  });

  final Area? area;
  final int? minPrice;
  final int? maxPrice;
  final ItemSort sort;
}

/// Bottom sheet with area, price and sort. Returns null when dismissed.
Future<FilterChoice?> showFilterSheet(BuildContext context, ItemQuery query) {
  return showModalBottomSheet<FilterChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FilterSheet(query: query),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.query});

  final ItemQuery query;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Area? _area = widget.query.area;
  late int _priceIndex = _initialPriceIndex();
  late ItemSort _sort = widget.query.sort;

  int _initialPriceIndex() {
    final index = _priceOptions.indexWhere(
      (o) => o.min == widget.query.minPrice && o.max == widget.query.maxPrice,
    );
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Area', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All areas'),
                  selected: _area == null,
                  onSelected: (_) => setState(() => _area = null),
                ),
                for (final area in Area.values)
                  ChoiceChip(
                    label: Text(area.label),
                    selected: _area == area,
                    onSelected: (_) => setState(() => _area = area),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Price per day', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _priceOptions.length; i++)
                  ChoiceChip(
                    label: Text(_priceOptions[i].label),
                    selected: _priceIndex == i,
                    onSelected: (_) => setState(() => _priceIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sort by', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final sort in ItemSort.values)
                  ChoiceChip(
                    label: Text(_sortLabel(sort)),
                    selected: _sort == sort,
                    onSelected: (_) => setState(() => _sort = sort),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Show items',
              onPressed: () {
                final price = _priceOptions[_priceIndex];
                Navigator.of(context).pop(
                  FilterChoice(
                    area: _area,
                    minPrice: price.min,
                    maxPrice: price.max,
                    sort: _sort,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Reset',
              onPressed: () => Navigator.of(context).pop(
                const FilterChoice(
                  area: null,
                  minPrice: null,
                  maxPrice: null,
                  sort: ItemSort.newest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
