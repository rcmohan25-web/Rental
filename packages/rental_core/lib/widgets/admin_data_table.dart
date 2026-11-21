import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Simple scrollable data table for admin screens.
/// Pass [columns] (header labels) and [rows] (cell widgets per row).
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    required this.columns,
    required this.rows,
    this.emptyTitle = 'Nothing here yet',
    super.key,
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return EmptyState(title: emptyTitle);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              for (final c in columns) DataColumn(label: Text(c)),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [for (final cell in r) DataCell(cell)]),
            ],
          ),
        ),
      ),
    );
  }
}
