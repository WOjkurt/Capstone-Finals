import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';
import '../theme/app_theme.dart';

/// The academic term the Registrar is working in. One choice for the whole app
/// (Pending loads, Reports, the student Study load tab), starting on the active term.
class CurrentTerm extends ChangeNotifier {
  List<AcademicTermModel> _terms = [];
  String? _termId;
  bool _loading = false;
  bool _loaded = false;

  List<AcademicTermModel> get terms => _terms;
  String? get termId => _termId;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;

  AcademicTermModel? get term =>
      _terms.where((t) => t.termId == _termId).firstOrNull;

  /// Loads the terms once; keeps the current choice if it still exists, otherwise picks the active term.
  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    notifyListeners();
    try {
      _terms = await getIt<AcademicSetupRepository>().getTerms();
      if (_termId == null || !_terms.any((t) => t.termId == _termId)) {
        _termId = _terms.isEmpty
            ? null
            : _terms
                  .firstWhere((t) => t.isActive, orElse: () => _terms.first)
                  .termId;
      }
      _loaded = true;
    } catch (_) {
      // Pages show their own "no term" message; the next load() tries again.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void select(String? termId) {
    if (termId == null || termId == _termId) return;
    _termId = termId;
    notifyListeners();
  }
}

/// Makes one [CurrentTerm] available to every page below it.
class CurrentTermScope extends InheritedNotifier<CurrentTerm> {
  const CurrentTermScope({
    super.key,
    required CurrentTerm term,
    required super.child,
  }) : super(notifier: term);

  /// The app-wide term, or null when a page is shown on its own (for example in tests).
  static CurrentTerm? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentTermScope>()?.notifier;
}

/// Term dropdown bound to a [CurrentTerm]. Used in the menu, and on pages shown without the menu.
class CurrentTermPicker extends StatelessWidget {
  final CurrentTerm term;
  final bool dark;
  final double width;

  const CurrentTermPicker({
    super.key,
    required this.term,
    this.dark = false,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    final text = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    );
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        // A new key per term rebuilds the field when the choice changes elsewhere.
        key: ValueKey('current_term_picker_${term.termId}'),
        initialValue: term.termId,
        isExpanded: true,
        dropdownColor: dark ? const Color(0xFF13233F) : null,
        iconEnabledColor: dark ? const Color(0xFF8892B0) : null,
        style: text,
        decoration: InputDecoration(
          labelText: 'Term',
          labelStyle: TextStyle(color: dark ? const Color(0xFF8892B0) : null),
          isDense: true,
          filled: dark,
          fillColor: dark ? const Color(0xFF13233F) : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: const OutlineInputBorder(),
          enabledBorder: dark
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF172A45)),
                )
              : null,
        ),
        items: [
          for (final t in term.terms)
            DropdownMenuItem(
              value: t.termId,
              child: Text(
                '${t.label}${t.isActive ? ' (Active)' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        // The closed field shows just the term; the open list also marks the active one.
        selectedItemBuilder: (context) => [
          for (final t in term.terms) Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        onChanged: term.select,
      ),
    );
  }
}

/// For pages that work in one term. Follows the app-wide [CurrentTerm] when there is one;
/// a page shown on its own (for example in tests) keeps a private term.
mixin CurrentTermUser<T extends StatefulWidget> on State<T> {
  CurrentTerm? _shared;
  final CurrentTerm _own = CurrentTerm();
  String? _lastTermId;
  bool _attached = false;

  CurrentTerm get currentTerm => _shared ?? _own;

  /// Called when the chosen term changes (including the first time it is known).
  void onTermChanged(String termId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = CurrentTermScope.maybeOf(context);
    if (!_attached || !identical(scope, _shared)) {
      currentTerm.removeListener(_termListener);
      _shared = scope;
      currentTerm.addListener(_termListener);
      _attached = true;
      currentTerm.load();
      _termListener();
    }
  }

  void _termListener() {
    final id = currentTerm.termId;
    if (id != null && id != _lastTermId) {
      _lastTermId = id;
      // Defer so a page never fetches in the middle of a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onTermChanged(id);
      });
    }
  }

  @override
  void dispose() {
    currentTerm.removeListener(_termListener);
    _own.dispose();
    super.dispose();
  }
}
