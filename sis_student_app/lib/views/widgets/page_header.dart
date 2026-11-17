import 'package:flutter/material.dart';

/// Top of every page: a title that matches the menu label, an optional main
/// action, and an optional small refresh button.
class PageHeader extends StatelessWidget {
  final String title;

  /// An optional line of help under the title. Most pages leave this out — the
  /// title and the menu already say what the page is.
  final String? subtitle;
  final Widget? action;

  /// Shows a small refresh icon button. Refreshing is a minor action, so it never
  /// competes with the page's main (blue) button.
  final VoidCallback? onRefresh;

  /// Shows a back arrow before the title, for pages opened on top of another page.
  final VoidCallback? onBack;

  /// Extra controls under the title, such as the term picker.
  final Widget? below;

  /// On phones the app bar already names the page, so a header carrying nothing
  /// but a refresh button is an empty white strip and collapses away. Pages that
  /// have no pull-to-refresh of their own set this false to keep the button.
  final bool collapseWhenEmptyOnPhone;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onRefresh,
    this.onBack,
    this.below,
    this.collapseWhenEmptyOnPhone = true,
  });

  @override
  Widget build(BuildContext context) {
    // Students mostly use phones: tighter spacing and smaller text there.
    final phone = MediaQuery.sizeOf(context).width < 700;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    // Nothing left to show on a phone once the title lives in the app bar.
    if (phone &&
        collapseWhenEmptyOnPhone &&
        !hasSubtitle &&
        below == null &&
        action == null &&
        onBack == null) {
      return const SizedBox.shrink();
    }

    final backButton = onBack == null
        ? null
        : IconButton(
            key: const ValueKey('page_back_button'),
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          );

    final refreshButton = onRefresh == null
        ? null
        : IconButton(
            key: const ValueKey('page_refresh_button'),
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF475569),
            style: IconButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

    Widget wrap(Widget child) => Container(
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 16 : 32,
            vertical: phone ? 10 : 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: child,
        );

    // On a phone with no title or subtitle to show, the refresh button would
    // sit alone above the controls. Put them on one line instead.
    if (phone && !hasSubtitle && below != null) {
      return wrap(Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (backButton != null) ...[backButton, const SizedBox(width: 8)],
          Expanded(child: below!),
          if (refreshButton != null) ...[
            const SizedBox(width: 12),
            refreshButton,
          ],
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ));
    }

    final top = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (backButton != null) ...[
            backButton,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // On phones the app bar already names the page, so the title
                // is not repeated here.
                if (!phone)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                if (hasSubtitle) ...[
                  if (!phone) const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: phone ? 13 : 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (refreshButton != null) ...[
            const SizedBox(width: 16),
            refreshButton,
          ],
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
    );
    return wrap(
      below == null
          ? top
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [top, const SizedBox(height: 12), below!],
            ),
    );
  }
}
