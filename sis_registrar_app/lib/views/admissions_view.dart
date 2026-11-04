import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/applications_bloc.dart';
import '../blocs/dashboard_bloc.dart';
import '../blocs/link_accounts_bloc.dart';
import '../blocs/responses_bloc.dart';
import '../theme/app_theme.dart';
import 'applications_view.dart';
import 'link_accounts_view.dart';
import 'responses_view.dart';
import 'widgets/page_header.dart';

/// The three admission steps on one page: form responses, applications, and creating logins.
class AdmissionsView extends StatefulWidget {
  /// Which tab is showing; links elsewhere in the app can change it.
  final ValueNotifier<int>? tab;

  const AdmissionsView({super.key, this.tab});

  @override
  State<AdmissionsView> createState() => _AdmissionsViewState();
}

class _AdmissionsViewState extends State<AdmissionsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.tab?.value ?? 0,
  );

  @override
  void initState() {
    super.initState();
    widget.tab?.addListener(_followLink);
  }

  void _followLink() => _tabs.animateTo(widget.tab!.value);

  @override
  void dispose() {
    widget.tab?.removeListener(_followLink);
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    switch (_tabs.index) {
      case 0:
        context.read<ResponsesBloc>().add(LoadResponses());
      case 1:
        final state = context.read<ApplicationsBloc>().state;
        context.read<ApplicationsBloc>().add(
          LoadApplications(
            statusFilter: state is ApplicationsLoaded
                ? state.statusFilter
                : null,
          ),
        );
      case 2:
        context.read<LinkAccountsBloc>().add(LoadApprovedApplications());
    }
    context.read<DashboardBloc>().add(LoadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Admissions',
            subtitle:
                'New students: form responses become applications, then approved applicants get a login.',
            onRefresh: _refresh,
          ),
          Container(
            color: Colors.white,
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, d) {
                String label(String name, int Function(DashboardLoaded) count) {
                  final n = d is DashboardLoaded ? count(d) : 0;
                  return n > 0 ? '$name ($n)' : name;
                }

                return TabBar(
                  key: const ValueKey('admissions_tabs'),
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      text: label(
                        '1. Form responses',
                        (d) => d.unprocessedResponsesCount,
                      ),
                    ),
                    Tab(
                      text: label(
                        '2. Applications',
                        (d) => d.pendingApplicationsCount,
                      ),
                    ),
                    Tab(
                      text: label(
                        '3. Create logins',
                        (d) => d.approvedApplicationsCount,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                ResponsesView(showHeader: false),
                ApplicationsView(showHeader: false),
                LinkAccountsView(showHeader: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
