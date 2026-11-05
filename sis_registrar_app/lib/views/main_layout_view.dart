import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/dashboard_bloc.dart';
import '../services/current_term.dart';
import '../theme/app_theme.dart';
import 'admissions_view.dart';
import 'clearance_view.dart';
import 'corrections_view.dart';
import 'dashboard_view.dart';
import 'pending_loads_view.dart';
import 'reports_view.dart';
import 'setup_view.dart';
import 'staff_management_view.dart';

class MainLayoutView extends StatefulWidget {
  final AuthenticatedState auth;

  const MainLayoutView({super.key, required this.auth});

  /// Menu items in display order: only places to go, nothing else. 'gapBefore' adds a little
  /// space to separate groups; 'badge' names the count shown next to the item.
  static List<Map<String, dynamic>> buildNavItems({
    required int role,
    required String roleName,
  }) {
    final isAdmin = role == 1 || roleName.toLowerCase() == 'admin';
    return [
      {
        'title': 'Dashboard',
        'icon': Icons.dashboard_outlined,
        'activeIcon': Icons.dashboard_rounded,
      },
      {
        'title': 'Admissions',
        'icon': Icons.how_to_reg_outlined,
        'activeIcon': Icons.how_to_reg_rounded,
        'badge': 'admissions',
      },
      {
        'title': 'Students',
        'icon': Icons.people_outline_rounded,
        'activeIcon': Icons.people_rounded,
      },
      {
        'title': 'Pending loads',
        'icon': Icons.pending_actions_outlined,
        'activeIcon': Icons.pending_actions_rounded,
        'badge': 'pendingLoads',
      },
      {
        'title': 'Grade corrections',
        'icon': Icons.assignment_late_outlined,
        'activeIcon': Icons.assignment_late_rounded,
        'badge': 'corrections',
      },
      {
        'title': 'Reports',
        'icon': Icons.bar_chart_outlined,
        'activeIcon': Icons.bar_chart_rounded,
        'gapBefore': true,
      },
      {
        'title': 'Setup',
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings_rounded,
      },
      if (isAdmin)
        {
          'title': 'Staff Management',
          'icon': Icons.admin_panel_settings_outlined,
          'activeIcon': Icons.admin_panel_settings_rounded,
        },
    ];
  }

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  int _selectedIndex = 0;

  /// The term every page works in. Pages show their own picker, all bound to this one choice.
  final _currentTerm = CurrentTerm();

  /// Ctrl+K puts the cursor in the Students page search.
  final _studentSearchFocus = FocusNode();

  /// Which tab Admissions and Reports open on, so links (e.g. from the dashboard) land on the right one.
  final _admissionsTab = ValueNotifier<int>(0);
  final _reportsTab = ValueNotifier<int>(0);

  static const double _compactBelow = 1280;

  @override
  void initState() {
    super.initState();
    _currentTerm.load();
  }

  @override
  void dispose() {
    _currentTerm.dispose();
    _studentSearchFocus.dispose();
    _admissionsTab.dispose();
    _reportsTab.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _navItems => MainLayoutView.buildNavItems(
    role: widget.auth.role,
    roleName: widget.auth.roleName,
  );

  void _onSelectTab(int index) => setState(() => _selectedIndex = index);

  /// Opens a page by name. Names of tabs inside Admissions and Reports open that tab.
  void _openPage(String title) {
    const admissionsTabs = ['Form responses', 'Applications', 'Create logins'];
    if (admissionsTabs.contains(title)) {
      _admissionsTab.value = admissionsTabs.indexOf(title);
      title = 'Admissions';
    } else if (title == 'Activity log') {
      _reportsTab.value = ReportsView.activityLogTab;
      title = 'Reports';
    } else if (title == 'Reports') {
      _reportsTab.value = ReportsView.termReportsTab;
    }
    final index = _navItems.indexWhere((i) => i['title'] == title);
    if (index >= 0) _onSelectTab(index);
  }

  void _focusStudentSearch() {
    _openPage('Students');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _studentSearchFocus.requestFocus(),
    );
  }

  Widget _pageFor(String title) {
    switch (title) {
      case 'Dashboard':
        return DashboardView(onNavigate: _openPage);
      case 'Admissions':
        return AdmissionsView(tab: _admissionsTab);
      case 'Students':
        return ClearanceView(searchFocus: _studentSearchFocus);
      case 'Pending loads':
        return const PendingLoadsView();
      case 'Grade corrections':
        return const CorrectionsView();
      case 'Reports':
        return ReportsView(tab: _reportsTab);
      case 'Setup':
        return const SetupView();
      case 'Staff Management':
        return const StaffManagementView();
    }
    return const SizedBox.shrink();
  }

  /// Counts shown next to menu items, from the dashboard's data.
  int _badgeCount(String? badge, DashboardState state) {
    if (badge == null || state is! DashboardLoaded) return 0;
    return switch (badge) {
      'admissions' =>
        state.unprocessedResponsesCount +
            state.pendingApplicationsCount +
            state.approvedApplicationsCount,
      'corrections' => state.pendingCorrectionsCount,
      'pendingLoads' => state.pendingLoadsCount,
      _ => 0,
    };
  }

  /// Shows a confirmation dialog before signing out.
  /// The [LogoutRequested] event is only dispatched if the user confirms.
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "You'll need to sign in again to access the Registrar portal.",
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

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final currentIndex = _selectedIndex < navItems.length ? _selectedIndex : 0;
    final compact = MediaQuery.sizeOf(context).width < _compactBelow;

    return CurrentTermScope(
      term: _currentTerm,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _focusStudentSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _focusStudentSearch,
        },
        // Shortcuts only fire while something below has focus, so the page itself takes focus at start.
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(navItems, currentIndex, compact: compact),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex,
                    children: [
                      for (final item in navItems)
                        _pageFor(item['title'] as String),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        : 'R';

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          'Registrar',
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
            child: BlocBuilder<DashboardBloc, DashboardState>(
              // Keep the last counts while the dashboard reloads, so badges don't flicker.
              buildWhen: (prev, next) =>
                  next is DashboardLoaded || next is DashboardError,
              builder: (context, dashboard) => ListView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
                children: [
                  for (var i = 0; i < navItems.length; i++) ...[
                    if (navItems[i]['gapBefore'] == true)
                      const SizedBox(height: 20),
                    _navItem(
                      navItems[i],
                      i == currentIndex,
                      _badgeCount(navItems[i]['badge'] as String?, dashboard),
                      () => _onSelectTab(i),
                      compact,
                    ),
                  ],
                ],
              ),
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
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.sidebarBorder,
                          foregroundColor: Colors.white,
                          child: Text(
                            initial,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      IconButton(
                        key: const ValueKey('sign_out_button'),
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: AppColors.sidebarTextMuted,
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.sidebarBorder,
                        foregroundColor: Colors.white,
                        child: Text(
                          initial,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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
                      IconButton(
                        key: const ValueKey('sign_out_button'),
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        color: AppColors.sidebarTextMuted,
                        onPressed: () => _confirmLogout(context),
                      ),
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
    int count,
    VoidCallback onTap,
    bool compact,
  ) {
    final title = item['title'] as String;
    final icon = Icon(
      selected ? item['activeIcon'] as IconData : item['icon'] as IconData,
      size: 22,
      color: selected ? Colors.white : const Color(0xFFB4C0D6),
    );
    final badge = count > 0
        ? Container(
            key: ValueKey('nav_badge_$title'),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? Colors.white : AppColors.accentAmber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : const Color(0xFF0A192F),
              ),
            ),
          )
        : null;

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
            ? Stack(
                alignment: Alignment.center,
                children: [
                  icon,
                  if (badge != null)
                    Positioned(
                      top: 7,
                      right: 9,
                      child: Container(
                        key: ValueKey('nav_dot_$title'),
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.accentAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              )
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
                  if (badge != null) ...[const SizedBox(width: 8), badge],
                ],
              ),
      ),
    );
    return compact
        ? Tooltip(message: count > 0 ? '$title ($count)' : title, child: tile)
        : tile;
  }
}
