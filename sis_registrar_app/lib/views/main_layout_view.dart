import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../theme/app_theme.dart';
import 'applications_view.dart';
import 'clearance_view.dart';
import 'corrections_view.dart';
import 'dashboard_view.dart';
import 'link_accounts_view.dart';
import 'responses_view.dart';
import 'setup_view.dart';

class MainLayoutView extends StatefulWidget {
  final AuthenticatedState auth;

  const MainLayoutView({super.key, required this.auth});

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _navItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard_rounded},
    {'title': 'Responses', 'icon': Icons.mark_email_unread_outlined, 'activeIcon': Icons.mark_email_unread_rounded},
    {'title': 'Applications', 'icon': Icons.description_outlined, 'activeIcon': Icons.description_rounded},
    {'title': 'Link accounts', 'icon': Icons.link_outlined, 'activeIcon': Icons.link_rounded},
    {'title': 'Clearance', 'icon': Icons.verified_user_outlined, 'activeIcon': Icons.verified_user_rounded},
    {'title': 'Setup', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings_rounded},
    {'title': 'Corrections', 'icon': Icons.assignment_late_outlined, 'activeIcon': Icons.assignment_late_rounded},
  ];

  void _onSelectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar
          _buildSidebar(context),
          // Content Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                DashboardView(onNavigate: _onSelectTab),
                const ResponsesView(),
                const ApplicationsView(),
                const LinkAccountsView(),
                const ClearanceView(),
                const SetupView(),
                const CorrectionsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
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
                      'Registrar System',
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
              itemCount: _navItems.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final item = _navItems[i];
                final isSelected = _selectedIndex == i;

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
                            : 'R',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  label: const Text('Sign Out', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
