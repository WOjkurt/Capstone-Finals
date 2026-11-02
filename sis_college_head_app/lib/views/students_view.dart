import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/students_bloc.dart';
import '../models/grading_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/student_load_dialog.dart';

class StudentsView extends StatefulWidget {
  const StudentsView({super.key});

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<StudentsBloc>().add(StudentsStarted());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search() {
    context.read<StudentsBloc>().add(StudentsSearchRequested(_searchCtrl.text));
  }

  void _openStudent(StudentsState state, UserSearchResultModel student) {
    final term = state.selectedTerm;
    if (term == null) return;
    StudentLoadDialog.show(
      context,
      student: student,
      termId: term.termId,
      termLabel: term.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentsBloc, StudentsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Students',
              subtitle:
                  'Search by LRN or name, then build a study load for the Registrar to approve.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 260, child: _buildTermDropdown(state)),
                  SizedBox(
                    width: 380,
                    child: TextField(
                      key: const ValueKey('student_search_field'),
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        labelText: 'LRN, name or email',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('student_search_button'),
                    onPressed: state.isSearching ? null : _search,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                child: Text(state.errorMessage!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            Expanded(child: _buildResults(state)),
          ],
        );
      },
    );
  }

  Widget _buildTermDropdown(StudentsState state) {
    if (state.isLoadingTerms) {
      return const LinearProgressIndicator();
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('term_dropdown'),
      initialValue: state.selectedTermId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Term',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: state.terms
          .map((t) => DropdownMenuItem(
                value: t.termId,
                child: Text(t.isActive ? '${t.label} (active)' : t.label,
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          context.read<StudentsBloc>().add(StudentsTermSelected(v));
        }
      },
    );
  }

  Widget _buildResults(StudentsState state) {
    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.hasSearched) {
      return const Center(
        child: Text('Type an LRN or name and press Search.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (state.results.isEmpty) {
      return Center(
        child: Text('No students found for "${state.query}".',
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    final canOpen = state.selectedTerm != null;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final s = state.results[i];
        final details = <String>[
          if (s.programCode != null && s.programCode!.isNotEmpty) s.programCode!,
          if (s.yearLevel != null) 'Year ${s.yearLevel}',
          'LRN: ${(s.lrn != null && s.lrn!.isNotEmpty) ? s.lrn : 'none'}',
          s.email,
        ];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(s.fullName.isNotEmpty ? s.fullName : s.email,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(details.join(' · ')),
            trailing: OutlinedButton(
              onPressed: canOpen ? () => _openStudent(state, s) : null,
              child: const Text('Open'),
            ),
            onTap: canOpen ? () => _openStudent(state, s) : null,
          ),
        );
      },
    );
  }
}
