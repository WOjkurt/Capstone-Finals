import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../theme/app_theme.dart';
import 'faculty_view.dart';
import 'students_view.dart';
import 'widgets/password_reset.dart';

class MainLayoutView extends StatefulWidget {
  final AuthenticatedState auth;

  const MainLayoutView({super.key, required this.auth});

  /// Menu items in display order: only places to go.
  static List<Map<String, dynamic>> buildNavItems() {
    return [
      {'title': 'Students', 'icon': Icons.school_outlined, 'activeIcon': Icons.school_rounded},
      {'title': 'Faculty', 'icon': Icons.groups_outlined, 'activeIcon': Icons.groups_rounded},
    ];
  }

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  int _selectedIndex = 0;

  List<Map<String, dynamic>> get _navItems => MainLayoutView.buildNavItems();

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
          "You'll need to sign in again to access the College Head portal.",
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

  static const double _compactBelow = 1280;

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final currentIndex = _selectedIndex < navItems.length ? _selectedIndex : 0;
    final compact = MediaQuery.sizeOf(context).width < _compactBelow;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(navItems, currentIndex, compact: compact),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: const [
                StudentsView(),
                FacultyView(),
              ],
            ),
          ),
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
        : 'C';
    final signOut = IconButton(
      key: const ValueKey('sign_out_button'),
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_rounded, size: 20),
      color: AppColors.sidebarTextMuted,
      onPressed: () => _confirmLogout(context),
    );
    final changePassword = IconButton(
      key: const ValueKey('change_password_button'),
      tooltip: 'Change password',
      icon: const Icon(Icons.lock_reset_rounded, size: 20),
      color: AppColors.sidebarTextMuted,
      onPressed: () => confirmChangePassword(context, widget.auth.email),
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
                      children: [
                        const Text(
                          'DBTC-CEBU',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'College Head',
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
                      changePassword,
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
                      changePassword,
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
}
