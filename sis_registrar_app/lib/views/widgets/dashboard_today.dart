import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/activity_log_models.dart';
import '../../models/report_models.dart';
import '../../repositories/activity_log_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/current_term.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Dashboard "today" section: enrollment in the current term per program, and the latest activity.
/// Both parts are extras, so a failure just hides that part.
class DashboardToday extends StatefulWidget {
  final void Function(String pageTitle)? onNavigate;

  const DashboardToday({super.key, this.onNavigate});

  @override
  State<DashboardToday> createState() => _DashboardTodayState();
}

class _DashboardTodayState extends State<DashboardToday> with CurrentTermUser {
  List<EnrollmentSummaryRow>? _enrollment;
  List<ActivityLogEntry>? _activity;

  @override
  void onTermChanged(String termId) {
    _loadEnrollment(termId);
    _loadActivity();
  }

  Future<void> _loadEnrollment(String termId) async {
    try {
      final rows = await getIt<ReportRepository>().enrollmentSummary(termId);
      if (mounted) setState(() => _enrollment = rows);
    } catch (_) {
      if (mounted) setState(() => _enrollment = null);
    }
  }

  Future<void> _loadActivity() async {
    try {
      final page = await getIt<ActivityLogRepository>().search(pageSize: 5);
      if (mounted) setState(() => _activity = page.items);
    } catch (_) {
      if (mounted) setState(() => _activity = null);
    }
  }

  Widget _card({required String title, Widget? trailing, required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _enrollmentCard() {
    final rows = _enrollment;
    final byProgram = <String, (int, int)>{};
    for (final r in rows ?? <EnrollmentSummaryRow>[]) {
      final (e, p) = byProgram[r.programCode] ?? (0, 0);
      byProgram[r.programCode] = (e + r.enrolledStudents, p + r.pendingOnlyStudents);
    }
    final totalEnrolled = byProgram.values.fold<int>(0, (s, v) => s + v.$1);
    final totalPending = byProgram.values.fold<int>(0, (s, v) => s + v.$2);

    return _card(
      title: 'Enrollment',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentTerm.terms.isNotEmpty) CurrentTermPicker(term: currentTerm, width: 210),
          TextButton(
            onPressed: () => widget.onNavigate?.call('Reports'),
            child: const Text('Reports'),
          ),
        ],
      ),
      child: rows == null
          ? const Text('Enrollment numbers are not available right now.',
              style: TextStyle(color: AppColors.textSecondary))
          : rows.isEmpty
              ? const Text('No students enrolled in this term yet.', style: TextStyle(color: AppColors.textSecondary))
              : Column(
                  key: const ValueKey('dashboard_enrollment'),
                  children: [
                    for (final e in byProgram.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            Expanded(
                              child: Text('${e.value.$1} enrolled',
                                  style: const TextStyle(color: AppColors.textPrimary)),
                            ),
                            if (e.value.$2 > 0)
                              Text('${e.value.$2} pending',
                                  style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                        Expanded(
                          child: Text('$totalEnrolled enrolled', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (totalPending > 0)
                          Text('$totalPending pending',
                              style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _activityCard() {
    final items = _activity;
    return _card(
      title: 'Recent activity',
      trailing: TextButton(
        onPressed: () => widget.onNavigate?.call('Activity log'),
        child: const Text('See all'),
      ),
      child: items == null
          ? const Text('Activity is not available right now.', style: TextStyle(color: AppColors.textSecondary))
          : items.isEmpty
              ? const Text('Nothing recorded yet.', style: TextStyle(color: AppColors.textSecondary))
              : Column(
                  key: const ValueKey('dashboard_activity'),
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(Icons.circle, size: 7, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.studentName == null ? e.summary : '${e.studentName}: ${e.summary}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text('${e.actorName} · ${formatDateTime(e.occurredAt)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth > 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _enrollmentCard()),
                const SizedBox(width: 20),
                Expanded(child: _activityCard()),
              ],
            )
          : Column(children: [_enrollmentCard(), const SizedBox(height: 20), _activityCard()]),
    );
  }
}
