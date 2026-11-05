import 'package:flutter/material.dart';

/// Top of every page: a title that matches the menu label, one line of help,
/// an optional main action, and an optional small refresh button.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  /// Shows a small refresh icon button. Refreshing is a minor action, so it never
  /// competes with the page's main (blue) button.
  final VoidCallback? onRefresh;

  /// Shows a back arrow before the title, for pages opened on top of another page.
  final VoidCallback? onBack;

  /// Extra controls under the title, such as the term picker.
  final Widget? below;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.onRefresh,
    this.onBack,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    // Students mostly use phones: tighter spacing and smaller text there.
    final phone = MediaQuery.sizeOf(context).width < 700;
    final top = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            IconButton(
              key: const ValueKey('page_back_button'),
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: phone ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: phone ? 13 : 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 16),
            IconButton(
              key: const ValueKey('page_refresh_button'),
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: const Color(0xFF475569),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 32, vertical: phone ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: below == null
          ? top
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [top, const SizedBox(height: 12), below!],
            ),
    );
  }
}
