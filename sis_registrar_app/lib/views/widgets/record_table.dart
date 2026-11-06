import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RecordColumn {
  final String label;
  final double flex;
  final bool center;
  const RecordColumn(this.label, this.flex, {this.center = false});
}

class RecordRow {
  final List<String> cells;
  final Color? color;
  final Key? key;

  /// Widgets that replace a cell's text, by column number (buttons, a Forced label).
  final Map<int, Widget> widgets;
  const RecordRow(this.cells, {this.color, this.key, this.widgets = const {}});
}

/// Row highlights on screen. The printouts use shades of gray for the same groups.
class RecordColors {
  static const taken = Color(0xFFF0FDF4);
  static const inProgress = Color(0xFFEFF6FF);
  static const notTaken = Color(0xFFF1F5F9);
  static const partial = Color(0xFFFEF9C3);
  static const droppedOrWithdrawn = Color(0xFFFFEDD5);
  static const failed = Color(0xFFFEE2E2);
}

/// A bordered table laid out like the printed records. It scrolls sideways on a narrow window.
class RecordTable extends StatelessWidget {
  final List<RecordColumn> columns;
  final List<RecordRow> rows;
  final List<String>? totals;
  final double minWidth;

  const RecordTable({super.key, required this.columns, required this.rows, this.totals, this.minWidth = 760});

  Widget _cell(String text, RecordColumn column, {bool bold = false, Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          text,
          textAlign: column.center ? TextAlign.center : TextAlign.left,
          style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Table(
              border: TableBorder.all(color: AppColors.border),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {for (final (i, c) in columns.indexed) i: FlexColumnWidth(c.flex)},
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    for (final c in columns)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                        child: Text(c.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                      ),
                  ],
                ),
                for (final r in rows)
                  TableRow(
                    decoration: BoxDecoration(color: r.color ?? Colors.white),
                    children: [
                      for (final (i, text) in r.cells.indexed)
                        r.widgets[i] != null
                            ? Padding(padding: const EdgeInsets.all(4), child: r.widgets[i])
                            : _cell(text, columns[i], key: i == 0 ? r.key : null),
                    ],
                  ),
                if (totals != null)
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.white),
                    children: [for (final (i, text) in totals!.indexed) _cell(text, columns[i], bold: true)],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small key explaining the row colors.
class RecordLegend extends StatelessWidget {
  final Map<String, Color> items;
  const RecordLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final e in items.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: e.value, border: Border.all(color: AppColors.border)),
              ),
              const SizedBox(width: 4),
              Text(e.key, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
        ],
      );
}
