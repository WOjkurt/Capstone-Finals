import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StatStripItem {
  final String label;
  final String count;
  final Color color;

  const StatStripItem({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Compact one-row summary card: equal-width count/label segments
/// separated by thin dividers.
class StatStrip extends StatelessWidget {
  final List<StatStripItem> items;

  const StatStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) _divider(),
                  _segment(items[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(StatStripItem item) {
    // Equal shares of the row, so all the numbers fit on a phone.
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.count,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: item.color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0xFFE2E8F0),
    );
  }
}
