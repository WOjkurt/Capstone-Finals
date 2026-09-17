import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class GradesEvent {}

class LoadGradesEvent extends GradesEvent {
  final String userId;
  final bool refresh;

  LoadGradesEvent({
    required this.userId,
    this.refresh = false,
  });
}

class SelectTermEvent extends GradesEvent {
  final AcademicTermModel term;
  final String userId;

  SelectTermEvent({
    required this.term,
    required this.userId,
  });
}

// ── States ───────────────────────────────────────────────────────────────────

abstract class GradesState {}

class GradesInitial extends GradesState {}

class GradesLoading extends GradesState {}

class GradesLoaded extends GradesState {
  final List<AcademicTermModel> terms;
  final AcademicTermModel? selectedTerm;
  final AcademicTermModel? activeTerm;
  final List<GradeClearanceModel> clearances;
  final List<GradeModel> grades;
  final bool isTermGradesLoading;

  GradesLoaded({
    required this.terms,
    required this.selectedTerm,
    required this.activeTerm,
    required this.clearances,
    required this.grades,
    this.isTermGradesLoading = false,
  });

  /// Evaluates whether grades are withheld for the currently selected term.
  /// Per the audit: If there is no clearance record for the term or isCleared == false,
  /// clearance is withheld.
  bool get isClearanceWithheld {
    if (selectedTerm == null) return false;
    final match = clearances.where((c) => c.termId == selectedTerm!.termId);
    if (match.isEmpty) return true;
    return !match.any((c) => c.isCleared);
  }

  int get totalSubjects => grades.length;

  int get passedCount => grades.where((g) {
        if (g.remarks == 1) return true;
        if (g.finalGrade != null && g.finalGrade! <= 3.0) return true;
        return false;
      }).length;

  int get failedCount => grades.where((g) {
        if (g.remarks == 2) return true;
        if (g.finalGrade != null && g.finalGrade! > 3.0) return true;
        return false;
      }).length;

  int get pendingFinalCount => grades.where((g) => g.finalGrade == null).length;

  GradesLoaded copyWith({
    List<AcademicTermModel>? terms,
    AcademicTermModel? selectedTerm,
    AcademicTermModel? activeTerm,
    List<GradeClearanceModel>? clearances,
    List<GradeModel>? grades,
    bool? isTermGradesLoading,
  }) {
    return GradesLoaded(
      terms: terms ?? this.terms,
      selectedTerm: selectedTerm ?? this.selectedTerm,
      activeTerm: activeTerm ?? this.activeTerm,
      clearances: clearances ?? this.clearances,
      grades: grades ?? this.grades,
      isTermGradesLoading: isTermGradesLoading ?? this.isTermGradesLoading,
    );
  }
}

class GradesError extends GradesState {
  final String message;

  GradesError(this.message);
}

// ── BLoC ────────────────────────────────────────────────────────────────────

class GradesBloc extends Bloc<GradesEvent, GradesState> {
  final StudentRepository _repository;

  GradesBloc(this._repository) : super(GradesInitial()) {
    on<LoadGradesEvent>(_onLoadGrades);
    on<SelectTermEvent>(_onSelectTerm);
  }

  Future<void> _onLoadGrades(
    LoadGradesEvent event,
    Emitter<GradesState> emit,
  ) async {
    if (!event.refresh && state is! GradesLoaded) {
      emit(GradesLoading());
    }

    try {
      final results = await Future.wait([
        _repository.getAllTerms(),
        _repository.getActiveTerm(),
        _repository.getGradeClearances(event.userId),
      ]);

      final terms = results[0] as List<AcademicTermModel>;
      final activeTerm = results[1] as AcademicTermModel?;
      final clearances = results[2] as List<GradeClearanceModel>;

      AcademicTermModel? selectedTerm;
      if (activeTerm != null) {
        selectedTerm = terms.firstWhere(
          (t) => t.termId == activeTerm.termId,
          orElse: () => activeTerm,
        );
      } else if (terms.isNotEmpty) {
        selectedTerm = terms.first;
      }

      List<GradeModel> grades = const [];
      if (selectedTerm != null) {
        grades = await _repository.getGrades(event.userId, selectedTerm.termId);
      }

      emit(GradesLoaded(
        terms: terms,
        selectedTerm: selectedTerm,
        activeTerm: activeTerm,
        clearances: clearances,
        grades: grades,
      ));
    } catch (e, st) {
      emit(GradesError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onSelectTerm(
    SelectTermEvent event,
    Emitter<GradesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GradesLoaded) return;

    if (currentState.selectedTerm?.termId == event.term.termId &&
        !currentState.isTermGradesLoading) {
      return;
    }

    emit(currentState.copyWith(
      selectedTerm: event.term,
      isTermGradesLoading: true,
    ));

    try {
      final grades = await _repository.getGrades(event.userId, event.term.termId);
      emit(currentState.copyWith(
        selectedTerm: event.term,
        grades: grades,
        isTermGradesLoading: false,
      ));
    } catch (e, st) {
      emit(GradesError(getFriendlyErrorMessage(e, st)));
    }
  }
}
