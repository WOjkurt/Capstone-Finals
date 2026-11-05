import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/clearance_bloc.dart';
import '../blocs/grades_bloc.dart';
import '../blocs/profile_bloc.dart';
import '../blocs/schedule_bloc.dart';
import '../injection.dart';
import '../theme/app_theme.dart';
import 'clearance_status_view.dart';
import 'grades_view.dart';
import 'profile_view.dart';
import 'schedule_view.dart';

/// Width breakpoint that separates mobile (bottom nav) from
/// tablet/desktop (left sidebar) layouts.
const double _kSidebarBreakpoint = 700.0;

/// Below this width the left menu shows icons only, as in the staff apps.
const double _kCompactBelow = 1280.0;

class MainLayoutView extends StatefulWidget {
  final AuthenticatedState auth;

  const MainLayoutView({super.key, required this.auth});

  static List<Map<String, dynamic>> buildNavItems({
    required int role,
    required String roleName,
  }) {
    return [
      {
        'title': 'My Schedule',
        'label': 'Schedule', // short label for BottomNavigationBar
        'icon': Icons.calendar_today_outlined,
        'activeIcon': Icons.calendar_today_rounded,
      },
      {
        'title': 'My Grades',
        'label': 'Grades',
        'icon': Icons.grade_outlined,
        'activeIcon': Icons.grade_rounded,
      },
      {
        'title': 'Clearance Status',
        'label': 'Clearance',
        'icon': Icons.verified_user_outlined,
        'activeIcon': Icons.verified_user_rounded,
      },
      {
        'title': 'Profile',
        'label': 'Profile',
        'icon': Icons.person_outline_rounded,
        'activeIcon': Icons.person_rounded,
      },
    ];
  }

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  int _selectedIndex = 0;

  List<Map<String, dynamic>> get _navItems => MainLayoutView.buildNavItems(
        role: widget.auth.role,
        roleName: widget.auth.roleName,
      );

  void _onSelectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "You'll need to sign in again to access the portal.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF991B1B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(LogoutRequested());
    }
  }

  /// The shared content area — same for both layouts.
  Widget _buildContentStack(int currentIndex) {
    return IndexedStack(
      index: currentIndex,
      children: [
        BlocProvider<ScheduleBloc>(
          create: (_) => getIt<ScheduleBloc>(),
          child: ScheduleView(userId: widget.auth.userId),
        ),
        BlocProvider<GradesBloc>(
          create: (_) => getIt<GradesBloc>(),
          child: GradesView(userId: widget.auth.userId),
        ),
        BlocProvider<ClearanceBloc>(
          create: (_) => getIt<ClearanceBloc>(),
          child: ClearanceStatusView(userId: widget.auth.userId),
        ),
        BlocProvider<ProfileBloc>(
          create: (_) => getIt<ProfileBloc>(),
          child: ProfileView(email: widget.auth.email),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final currentIndex = _selectedIndex < navItems.length ? _selectedIndex : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kSidebarBreakpoint;

        if (isWide) {
          return _buildWideLayout(
            context,
            navItems,
            currentIndex,
            compact: constraints.maxWidth < _kCompactBelow,
          );
        } else {
          return _buildNarrowLayout(context, navItems, currentIndex);
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Wide layout: left menu (≥ 700 px), icons only below 1280 px
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    List<Map<String, dynamic>> navItems,
    int currentIndex, {
    required bool compact,
  }) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(navItems, currentIndex, compact: compact),
          Expanded(child: _buildContentStack(currentIndex)),
        ],
      ),
    );
  }

  /// The menu: logo, the page links, and who is signed in. On smaller (laptop) screens it shows
  /// icons only, with each name on hover.
  Widget _buildSidebar(
    List<Map<String, dynamic>> navItems,
    int currentIndex, {
    required bool compact,
  }) {
    final logo = Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset('assets/images/dbtc_logo.png', fit: BoxFit.contain),
    );
    final initial = widget.auth.displayName.isNotEmpty
        ? widget.auth.displayName[0].toUpperCase()
        : 'S';
    final signOut = IconButton(
      key: const ValueKey('sign_out_button'),
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_rounded, size: 20),
      color: AppColors.sidebarTextMuted,
      onPressed: () => _confirmLogout(context),
    );
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.sidebarBorder,
      foregroundColor: Colors.white,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
    );

    return Container(
      key: compact
          ? const ValueKey('compact_sidebar')
          : const ValueKey('full_sidebar'),
      width: compact ? 76 : 248,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 18 : 22, 22, 18, 26),
            child: Row(
              children: [
                logo,
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'DBTC-CEBU',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Student Portal',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.sidebarTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
              children: [
                for (var i = 0; i < navItems.length; i++) ...[
                  if (navItems[i]['gapBefore'] == true)
                    const SizedBox(height: 20),
                  _navItem(
                    navItems[i],
                    i == currentIndex,
                    () => _onSelectTab(i),
                    compact,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 0 : 20,
              12,
              compact ? 0 : 12,
              18,
            ),
            child: compact
                ? Column(
                    children: [
                      Tooltip(
                        message:
                            '${widget.auth.displayName} (${widget.auth.roleName})',
                        child: avatar,
                      ),
                      const SizedBox(height: 6),
                      signOut,
                    ],
                  )
                : Row(
                    children: [
                      avatar,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.auth.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.auth.roleName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.sidebarTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      signOut,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    Map<String, dynamic> item,
    bool selected,
    VoidCallback onTap,
    bool compact,
  ) {
    final title = item['title'] as String;
    final icon = Icon(
      selected ? item['activeIcon'] as IconData : item['icon'] as IconData,
      size: 22,
      color: selected ? Colors.white : const Color(0xFFB4C0D6),
    );
    final tile = InkWell(
      key: ValueKey('nav_$title'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: compact
            ? Center(child: icon)
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    return compact ? Tooltip(message: title, child: tile) : tile;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Narrow layout: top AppBar + bottom NavigationBar (< 700 px)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildNarrowLayout(
    BuildContext context,
    List<Map<String, dynamic>> navItems,
    int currentIndex,
  ) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _buildTopAppBar(context),
      body: _buildContentStack(currentIndex),
      bottomNavigationBar: _buildBottomNav(navItems, currentIndex),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.sidebarBg,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/dbtc_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DBTC-CEBU',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
              Text(
                'Student Portal',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.sidebarTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('sign_out_button'),
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, color: AppColors.sidebarTextMuted, size: 22),
          onPressed: () => _confirmLogout(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomNav(
    List<Map<String, dynamic>> navItems,
    int currentIndex,
  ) {
    // Match the sidebar's navy on phones too, with labels that read clearly on it.
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? Colors.white : const Color(0xFFB4C0D6),
          ),
        ),
      ),
      child: NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: _onSelectTab,
      backgroundColor: AppColors.sidebarBg,
      indicatorColor: AppColors.primary,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: navItems.map((item) {
        return NavigationDestination(
          icon: Icon(
            item['icon'] as IconData,
            color: const Color(0xFFB4C0D6),
          ),
          selectedIcon: Icon(
            item['activeIcon'] as IconData,
            color: Colors.white,
          ),
          label: item['label'] as String,
        );
      }).toList(),
      ),
    );
  }
}
