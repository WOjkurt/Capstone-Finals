import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/grading_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/study_load_pdf.dart';
import 'status_badge.dart';
import 'study_load_builder_dialog.dart';

/// View-only study load for one student and term. The College Head can
/// build a new load from here, which is always saved as Pending; only the
/// Registrar can finalize, reject or change a load.
class StudentLoadDialog extends StatefulWidget {
  final UserSearchResultModel student;
  final String termId;
  final String termLabel;

  const StudentLoadDialog({
    super.key,
    required this.student,
    required this.termId,
    required this.termLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSearchResultModel student,
    required String termId,
    required String termLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => StudentLoadDialog(
        student: student,
        termId: termId,
        termLabel: termLabel,
      ),
    );
  }

  @override
  State<StudentLoadDialog> createState() => _StudentLoadDialogState();
}

class _StudentLoadDialogState extends State<StudentLoadDialog> {
  List<ClassRosterItemModel> _loads = [];
  bool _isLoading = true;
  String? _error;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _fetchLoads();
  }

  Future<void> _fetchLoads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loads = await getIt<ClassRepository>()
          .getStudentStudyLoads(widget.student.userId, widget.termId);
      if (mounted) {
        setState(() {
          _loads = loads;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = getFriendlyErrorMessage(e, st);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openBuilder() async {
    await StudyLoadBuilderDialog.show(
      context,
      student: widget.student,
      initialTermId: widget.termId,
      initialTermLabel: widget.termLabel,
      // Always Pending in this app, even when an Admin is signed in.
      isCollegeHead: true,
    );
    // Refresh even on partial saves, which close without returning true.
    if (mounted) {
      _fetchLoads();
    }
  }

  /// Prints the Official Enrollment Sheet: three copies (College Head, Registrar, student),
  /// Enrolled subjects only, so it can be printed once the Registrar has finalized the load.
  Future<void> _printOes() async {
    setState(() => _isPrinting = true);
    try {
      final s = widget.student;
      final data = StudyLoadPrintData(
        studentName: s.fullName,
        lrn: s.lrn,
        programCode: s.programCode,
        yearLevel: s.yearLevel,
        termLabel: widget.termLabel,
        loads: _loads,
      );
      final bytes = await buildStudyLoadPdf(data, logo: await loadSchoolLogo());
      final safeName = s.fullName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await printPdf(bytes, 'Enrollment_Sheet_$safeName.pdf');
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not print: ${getFriendlyErrorMessage(e, st)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final details = <String>[
      if (s.programCode != null && s.programCode!.isNotEmpty) s.programCode!,
      if (s.yearLevel != null) 'Year ${s.yearLevel}',
      'LRN: ${(s.lrn != null && s.lrn!.isNotEmpty) ? s.lrn : 'none'}',
    ];
    final pendingCount = _loads.where((l) => l.isPending).length;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.fullName.isNotEmpty ? s.fullName : s.email,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${details.join(' · ')}\nStudy load for ${widget.termLabel}',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: _buildBody(pendingCount),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('print_oes_button'),
          onPressed: (_isLoading || _isPrinting || !_loads.any((l) => l.isEnrolled))
              ? null
              : _printOes,
          icon: _isPrinting
              ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print Enrollment Sheet'),
        ),
        FilledButton.icon(
          key: const ValueKey('build_study_load_button'),
          onPressed: _isLoading ? null : _openBuilder,
          icon: const Icon(Icons.playlist_add_rounded, size: 18),
          label: const Text('Build study load'),
        ),
      ],
    );
  }

  Widget _buildBody(int pendingCount) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton(onPressed: _fetchLoads, child: const Text('Try again')),
        ],
      );
    }
    if (_loads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No subjects for this term yet. Use "Build study load" to propose some.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentAmberLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$pendingCount subject(s) waiting for Registrar approval.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _loads.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final load = _loads[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${load.subjectCode} - ${load.subjectTitle}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  load.className,
                  if (load.teacherName != null && load.teacherName!.isNotEmpty)
                    load.teacherName!,
                  if (load.isForced) 'Forced',
                ].join(' · ')),
                trailing: StatusBadge.forLoadStatus(load.loadStatus),
              );
            },
          ),
        ),
      ],
    );
  }
}
