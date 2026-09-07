import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/link_accounts_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import '../theme/app_theme.dart';

class LinkAccountsView extends StatefulWidget {
  const LinkAccountsView({super.key});

  @override
  State<LinkAccountsView> createState() => _LinkAccountsViewState();
}

class _LinkAccountsViewState extends State<LinkAccountsView> {
  final Map<String, TextEditingController> _emailControllers = {};

  @override
  void initState() {
    super.initState();
    final bloc = context.read<LinkAccountsBloc>();
    if (bloc.state is LinkAccountsInitial) {
      bloc.add(LoadApprovedApplications());
    }
  }

  @override
  void dispose() {
    for (var c in _emailControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String id) {
    return _emailControllers.putIfAbsent(id, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<LinkAccountsBloc, LinkAccountsState>(
        listener: (context, state) {
          if (state is LinkAccountsActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is LinkAccountsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Link Student Accounts',
                subtitle:
                    'Connect approved admissions to student system accounts by providing their registered email address.',
                action: ElevatedButton.icon(
                  onPressed: () => context
                      .read<LinkAccountsBloc>()
                      .add(LoadApprovedApplications()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, LinkAccountsState state) {
    if (state is LinkAccountsLoading || state is LinkAccountsInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final apps = (state is LinkAccountsLoaded)
        ? state.applications
        : (state is LinkAccountsError
            ? state.applications ?? []
            : <EnrollmentApplicationModel>[]);
    final programs = (state is LinkAccountsLoaded)
        ? state.programs
        : (state is LinkAccountsError
            ? state.programs ?? []
            : <AcademicProgramModel>[]);

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Approved Applications Awaiting Linking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All approved enrollment petitions have already been linked or none exist.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final programMap = {for (var p in programs) p.programId: p.programCode};
    final dateFormat = DateFormat('MMM dd, yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    horizontalMargin: 24,
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(
                        label: Text('Applicant Name',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Program',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Approved Date',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Status',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Student Account Email',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Action',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    rows: apps.map((app) {
                      final name = app.form?.fullName ?? 'Unnamed Applicant';
                      final prog =
                          programMap[app.programId] ?? 'Program #${app.programId}';
                      final dateStr = dateFormat.format(app.createdAt);
                      final emailCtrl = _getController(app.applicationId);
                      final isLinking = (state is LinkAccountsLoaded) &&
                          state.linkingApplicationId == app.applicationId;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(prog,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          DataCell(Text(dateStr)),
                          DataCell(
                            StatusBadge.success(label: 'Approved'),
                          ),
                          DataCell(
                            SizedBox(
                              width: 250,
                              child: TextField(
                                controller: emailCtrl,
                                decoration: InputDecoration(
                                  hintText: 'student@dbtc-cebu.edu.ph',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            ElevatedButton.icon(
                              onPressed: isLinking
                                  ? null
                                  : () {
                                      final email = emailCtrl.text.trim();
                                      if (email.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter an email address to link.'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }
                                      context.read<LinkAccountsBloc>().add(
                                            LinkAccountSubmitted(
                                              app.applicationId,
                                              email,
                                            ),
                                          );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              icon: isLinking
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.link, size: 16),
                              label: Text(isLinking ? 'Linking...' : 'Link Account',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
