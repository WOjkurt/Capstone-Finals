import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/schedule_bloc.dart';
import '../injection.dart';
import '../theme/app_theme.dart';
import 'placeholder_views.dart';
import 'schedule_view.dart';

/// Width breakpoint that separates mobile (bottom nav) from
/// tablet/desktop (left sidebar) layouts.
const double _kSidebarBreakpoint = 700.0;

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
        const MyGradesPlaceholderView(),
        const ClearanceStatusPlaceholderView(),
        const ProfilePlaceholderView(),
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
          return _buildWideLayout(context, navItems, currentIndex);
        } else {
          return _buildNarrowLayout(context, navItems, currentIndex);
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Wide layout: left sidebar (≥ 700 px)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    List<Map<String, dynamic>> navItems,
    int currentIndex,
  ) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(context, navItems, currentIndex),
          Expanded(child: _buildContentStack(currentIndex)),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<Map<String, dynamic>> navItems,
    int currentIndex,
  ) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Image.asset(
                    'assets/images/dbtc_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DBTC-CEBU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Student Portal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.sidebarTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.sidebarBorder),
          const SizedBox(height: 12),
          // Nav Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: navItems.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final item = navItems[i];
                final isSelected = currentIndex == i;

                return InkWell(
                  onTap: () => _onSelectTab(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? item['activeIcon'] as IconData
                              : item['icon'] as IconData,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : AppColors.sidebarTextMuted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.sidebarBorder),
          // User Info & Logout
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.sidebarBorder,
                      foregroundColor: const Color(0xFF60A5FA),
                      child: Text(
                        widget.auth.email.isNotEmpty
                            ? widget.auth.email[0].toUpperCase()
                            : 'S',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.auth.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.auth.roleName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF90CDF4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                    side: const BorderSide(color: AppColors.sidebarBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label:
                      const Text('Sign Out', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded,
              color: Color(0xFFF87171), size: 22),
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
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: _onSelectTab,
      // Match the sidebar's navy theme on mobile too
      backgroundColor: AppColors.sidebarBg,
      indicatorColor: AppColors.primary.withValues(alpha: 0.25),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: navItems.map((item) {
        return NavigationDestination(
          icon: Icon(
            item['icon'] as IconData,
            color: AppColors.sidebarTextMuted,
          ),
          selectedIcon: Icon(
            item['activeIcon'] as IconData,
            color: AppColors.primary,
          ),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }
}
