import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/grading_models.dart';
import '../models/hold_models.dart';
import '../repositories/accounting_repository.dart';
import '../repositories/hold_repository.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/page_header.dart';

/// The Accounting Office's one screen: find a student, see whether they are blocked over an
/// unpaid balance, and set or clear that block.
///
/// Deliberately not a payment ledger. The amount a student owes lives in the Accounting
/// Office's own system and is maintained there; duplicating it here would mean two answers to
/// the same question, and the stale one would be the one blocking a student who had already
/// paid. What this records is a decision -- held or cleared -- with a note, a name and a time.
class AccountingView extends StatefulWidget {
  const AccountingView({super.key});

  @override
  State<AccountingView> createState() => _AccountingViewState();
}

class _AccountingViewState extends State<AccountingView> {
  final _searchController = TextEditingController();
  final _accounting = getIt<AccountingRepository>();
  final _holds = getIt<HoldRepository>();

  List<UserSearchResultModel> _results = const [];
  UserSearchResultModel? _selected;
  List<EnrollmentHold> _studentHolds = const [];
  bool _searching = false;
  bool _loadingHolds = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EnrollmentHold? get _openUnpaidHold {
    for (final h in _studentHolds) {
      if (h.isOpen && h.reason == EnrollmentHoldReasons.unpaidBalance) return h;
    }
    return null;
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _accounting.searchStudents(query);
      if (!mounted) return;
      setState(() => _results = results);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(UserSearchResultModel student) async {
    setState(() {
      _selected = student;
      _studentHolds = const [];
      _loadingHolds = true;
      _error = null;
    });
    try {
      final holds = await _holds.forStudent(student.userId);
      if (!mounted) return;
      setState(() => _studentHolds = holds);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingHolds = false);
    }
  }

  /// Both directions ask for a note, because six weeks later "why was this student blocked?"
  /// is a question somebody will actually have to answer.
  Future<String?> _askForNote({required String title, required String hint, required String confirmLabel}) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return note;
  }

  Future<void> _placeHold() async {
    final student = _selected;
    if (student == null) return;
    final note = await _askForNote(
      title: 'Hold ${student.firstname} ${student.lastname}',
      hint: 'e.g. 2 installments outstanding',
      confirmLabel: 'Place hold',
    );
    if (note == null) return;

    try {
      await _holds.add(student.userId, reason: EnrollmentHoldReasons.unpaidBalance, note: note.isEmpty ? null : note);
      await _select(student);
      _toast('Hold placed. The student cannot re-enrol or see this term\'s grades until it is lifted.');
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> _liftHold() async {
    final student = _selected;
    final hold = _openUnpaidHold;
    if (student == null || hold == null) return;
    final note = await _askForNote(
      title: 'Clear ${student.firstname} ${student.lastname}',
      hint: 'e.g. paid in full, OR #12345',
      confirmLabel: 'Clear hold',
    );
    if (note == null) return;

    try {
      await _holds.remove(hold.holdId, note: note.isEmpty ? null : note);
      await _select(student);
      _toast('Cleared. The student can re-enrol and see this term\'s grades again.');
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : AppColors.accentGreenDark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Student accounts',
          subtitle: 'Place or clear an unpaid balance hold. The Registrar decides what happens next.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search by name or student number',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _search(_searchController.text),
                    ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _resultsList()),
              const VerticalDivider(width: 1),
              Expanded(flex: 3, child: _detailPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultsList() {
    if (_results.isEmpty && !_searching) {
      return const Center(child: Text('No students found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final s = _results[i];
        final selected = _selected?.userId == s.userId;
        return ListTile(
          selected: selected,
          selectedTileColor: AppColors.primaryLight,
          title: Text('${s.lastname}, ${s.firstname}'),
          subtitle: Text([
            if (s.studentId != null && s.studentId!.isNotEmpty) s.studentId!,
            if (s.programCode != null) s.programCode!,
            if (s.yearLevel != null) 'Year ${s.yearLevel}',
          ].join(' · ')),
          onTap: () => _select(s),
        );
      },
    );
  }

  Widget _detailPanel() {
    final student = _selected;
    if (student == null) {
      return const Center(child: Text('Select a student.'));
    }
    if (_loadingHolds) {
      return const Center(child: CircularProgressIndicator());
    }

    final hold = _openUnpaidHold;
    final held = hold != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${student.firstname} ${student.lastname}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text([
            if (student.studentId != null && student.studentId!.isNotEmpty) student.studentId!,
            if (student.programCode != null) student.programCode!,
            if (student.yearLevel != null) 'Year ${student.yearLevel}',
          ].join(' · '), style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: held ? AppColors.accentAmberLight : AppColors.accentGreenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(held ? Icons.pause_circle_filled : Icons.check_circle,
                      color: held ? AppColors.accentAmber : AppColors.accentGreenDark),
                  const SizedBox(width: 8),
                  Text(held ? 'On hold — unpaid balance' : 'Cleared',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                if (held) ...[
                  const SizedBox(height: 8),
                  if (hold.note != null) Text(hold.note!),
                  if (hold.addedByName != null)
                    Text('Placed by ${hold.addedByName}', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            held
                ? 'While this hold is open the student cannot enrol for next term, and this term\'s grades are hidden from them.'
                : 'This student has no unpaid balance hold. They can enrol and see their grades as normal.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          held
              ? FilledButton.icon(
                  onPressed: _liftHold,
                  icon: const Icon(Icons.check),
                  label: const Text('Clear hold'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreenDark),
                )
              : FilledButton.icon(
                  onPressed: _placeHold,
                  icon: const Icon(Icons.pause),
                  label: const Text('Place unpaid balance hold'),
                ),

          if (_studentHolds.where((h) => !h.isOpen).isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final h in _studentHolds.where((h) => !h.isOpen))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${h.reasonLabel} — cleared${h.removedByName != null ? ' by ${h.removedByName}' : ''}'
                  '${h.removalNote != null ? ' (${h.removalNote})' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.sidebarTextMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
