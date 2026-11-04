import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard_bloc.dart';
import '../theme/app_theme.dart';
import 'widgets/dashboard_today.dart';
import 'widgets/page_header.dart';

class DashboardView extends StatefulWidget {
  /// Opens a page by its menu title, e.g. 'Pending loads'.
  final void Function(String pageTitle)? onNavigate;

  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<DashboardBloc>();
    if (bloc.state is DashboardInitial) {
      bloc.add(LoadDashboardData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Dashboard',
            subtitle: 'What needs your attention today. Click a card to open it.',
            onRefresh: () =>
                context.read<DashboardBloc>().add(LoadDashboardData()),
          ),
          Expanded(
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                if (state is DashboardInitial) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (state is DashboardError) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFDC2626), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load dashboard',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF4B5563)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context
                                .read<DashboardBloc>()
                                .add(LoadDashboardData()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final loaded = state as DashboardLoaded;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Waiting for you',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = constraints.maxWidth > 1100
                              ? 5
                              : constraints.maxWidth > 700
                                  ? 3
                                  : 2;
                          final width = (constraints.maxWidth - (count - 1) * 20) / count;

                          return Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              _buildMetricCard(
                                title: 'New Responses',
                                count: loaded.unprocessedResponsesCount,
                                icon: Icons.mark_email_unread_outlined,
                                color: AppColors.accentAmber,
                                subtitle: 'To turn into applications',
                                width: width,
                                onTap: () => widget.onNavigate?.call('Form responses'),
                              ),
                              _buildMetricCard(
                                title: 'Applications',
                                count: loaded.pendingApplicationsCount,
                                icon: Icons.pending_actions_rounded,
                                color: AppColors.primary,
                                subtitle: 'Waiting for your review',
                                width: width,
                                onTap: () => widget.onNavigate?.call('Applications'),
                              ),
                              _buildMetricCard(
                                title: 'Need a Login',
                                count: loaded.approvedApplicationsCount,
                                icon: Icons.how_to_reg_rounded,
                                color: AppColors.accentGreen,
                                subtitle: 'Approved applicants',
                                width: width,
                                onTap: () => widget.onNavigate?.call('Create logins'),
                              ),
                              _buildMetricCard(
                                title: 'Pending Loads',
                                count: loaded.pendingLoadsCount,
                                icon: Icons.fact_check_outlined,
                                color: const Color(0xFF7C3AED),
                                subtitle: 'Students to finalize',
                                width: width,
                                onTap: () => widget.onNavigate?.call('Pending loads'),
                              ),
                              _buildMetricCard(
                                title: 'Grade Corrections',
                                count: loaded.pendingCorrectionsCount,
                                icon: Icons.assignment_late_outlined,
                                color: const Color(0xFFEF4444), // Red
                                subtitle: 'Teacher requests',
                                width: width,
                                onTap: () => widget.onNavigate?.call('Grade corrections'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      DashboardToday(onNavigate: widget.onNavigate),
                      const SizedBox(height: 28),
                      // The workflow guide is reference material, so it starts folded away.
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: const ValueKey('workflow_guide'),
                            leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                            title: const Text(
                              'How enrollment works',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                            children: [
                              _buildStepRow(
                                step: '1',
                                title: 'Form responses',
                                description: 'Turn the Google Form answers into enrollment applications.',
                              ),
                              const Divider(height: 24),
                              _buildStepRow(
                                step: '2',
                                title: 'Applications',
                                description: 'Check each application, then approve or reject it.',
                              ),
                              const Divider(height: 24),
                              _buildStepRow(
                                step: '3',
                                title: 'Create logins',
                                description: 'Give each approved applicant a student login for the student portal.',
                              ),
                              const Divider(height: 24),
                              _buildStepRow(
                                step: '4',
                                title: 'Study loads',
                                description: 'College Heads build study loads; finalize them under Pending loads.',
                              ),
                              const Divider(height: 24),
                              _buildStepRow(
                                step: '5',
                                title: 'Grades',
                                description: 'Release each term\'s grades in the student\'s Grade release tab, and review grade corrections.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required double width,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
