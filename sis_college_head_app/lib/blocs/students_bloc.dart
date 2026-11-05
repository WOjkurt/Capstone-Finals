import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/setup_repository.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class StudentsEvent {}

class StudentsStarted extends StudentsEvent {}

class StudentsTermSelected extends StudentsEvent {
  final String termId;
  StudentsTermSelected(this.termId);
}

class StudentsSearchRequested extends StudentsEvent {
  final String query;
  StudentsSearchRequested(this.query);
}

// State
class StudentsState {
  final List<AcademicTermModel> terms;
  final String? selectedTermId;
  final bool isLoadingTerms;
  final bool isSearching;
  final bool hasSearched;
  final String query;
  final List<UserSearchResultModel> results;
  final String? errorMessage;

  const StudentsState({
    this.terms = const [],
    this.selectedTermId,
    this.isLoadingTerms = false,
    this.isSearching = false,
    this.hasSearched = false,
    this.query = '',
    this.results = const [],
    this.errorMessage,
  });

  AcademicTermModel? get selectedTerm {
    for (final t in terms) {
      if (t.termId == selectedTermId) return t;
    }
    return null;
  }

  StudentsState copyWith({
    List<AcademicTermModel>? terms,
    String? selectedTermId,
    bool? isLoadingTerms,
    bool? isSearching,
    bool? hasSearched,
    String? query,
    List<UserSearchResultModel>? results,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudentsState(
      terms: terms ?? this.terms,
      selectedTermId: selectedTermId ?? this.selectedTermId,
      isLoadingTerms: isLoadingTerms ?? this.isLoadingTerms,
      isSearching: isSearching ?? this.isSearching,
      hasSearched: hasSearched ?? this.hasSearched,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Bloc
class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  final StudentRepository _studentRepo;
  final AcademicSetupRepository _setupRepo;

  StudentsBloc(this._studentRepo, this._setupRepo)
      : super(const StudentsState()) {
    on<StudentsStarted>(_onStarted);
    on<StudentsTermSelected>(_onTermSelected);
    on<StudentsSearchRequested>(_onSearchRequested);
  }

  Future<void> _onStarted(
      StudentsStarted event, Emitter<StudentsState> emit) async {
    emit(state.copyWith(isLoadingTerms: true, clearError: true));
    try {
      final terms = await _setupRepo.getTerms();
      // Newest first; default to the active term, else the newest one.
      terms.sort((a, b) {
        final byYear = b.schoolYear.compareTo(a.schoolYear);
        return byYear != 0 ? byYear : b.semester.compareTo(a.semester);
      });
      String? selected = terms.any((t) => t.termId == state.selectedTermId) ? state.selectedTermId : null;
      if (selected == null) {
        for (final t in terms) {
          if (t.isActive) selected = t.termId;
        }
      }
      selected ??= terms.isNotEmpty ? terms.first.termId : null;
      emit(state.copyWith(
        terms: terms,
        selectedTermId: selected,
        isLoadingTerms: false,
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isLoadingTerms: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  void _onTermSelected(
      StudentsTermSelected event, Emitter<StudentsState> emit) {
    emit(state.copyWith(selectedTermId: event.termId));
  }

  Future<void> _onSearchRequested(
      StudentsSearchRequested event, Emitter<StudentsState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(state.copyWith(
        query: '',
        results: const [],
        hasSearched: false,
        clearError: true,
      ));
      return;
    }

    emit(state.copyWith(query: query, isSearching: true, clearError: true));
    try {
      final results = await _studentRepo.searchStudents(query);
      emit(state.copyWith(
        results: results,
        isSearching: false,
        hasSearched: true,
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isSearching: false,
        hasSearched: true,
        results: const [],
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }
}
