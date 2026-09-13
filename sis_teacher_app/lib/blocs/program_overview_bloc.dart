import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../repositories/class_repository.dart';
import '../utils/error_handler.dart';


// ── Events ────────────────────────────────────────────────────────────────────

abstract class ProgramOverviewEvent {}

/// Loads all classes belonging to the Program Head's assigned academic program.
class LoadProgramClassesEvent extends ProgramOverviewEvent {
  final String? termId;
  final String? subjectId;

  LoadProgramClassesEvent({this.termId, this.subjectId});
}

/// Assigns (or reassigns) a teacher to a class, then refreshes the list.
class AssignTeacherEvent extends ProgramOverviewEvent {
  final String classId;
  final String? teacherUserId;

  /// The [termId] and [subjectId] are forwarded to the follow-up load so the
  /// same filter context is preserved after the assignment.
  final String? termId;
  final String? subjectId;

  AssignTeacherEvent({
    required this.classId,
    this.teacherUserId,
    this.termId,
    this.subjectId,
  });
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class ProgramOverviewState {}

class ProgramOverviewInitial extends ProgramOverviewState {}

class ProgramOverviewLoading extends ProgramOverviewState {}

class ProgramOverviewLoaded extends ProgramOverviewState {
  final List<ClassModel> classes;

  ProgramOverviewLoaded(this.classes);

  int get totalClasses => classes.length;

  int get activeFacultyCount {
    return classes
        .where((c) => c.userId != null && (c.teacherName?.trim().isNotEmpty ?? false))
        .map((c) => c.teacherName!.trim().toLowerCase())
        .toSet()
        .length;
  }

  int get unassignedCount => classes.where((c) => c.userId == null).length;
}

class ProgramOverviewError extends ProgramOverviewState {
  final String message;

  ProgramOverviewError(this.message);
}

/// Transient state emitted while an assignment is being saved.
class ProgramOverviewAssigning extends ProgramOverviewState {
  final String classId;
  ProgramOverviewAssigning(this.classId);
}

/// Emitted when an assignment fails — carries the previous data so the UI can
/// remain visible while showing the error message.
class ProgramOverviewAssignError extends ProgramOverviewState {
  final String message;
  final List<ClassModel> previousClasses;

  ProgramOverviewAssignError(this.message, this.previousClasses);
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

class ProgramOverviewBloc
    extends Bloc<ProgramOverviewEvent, ProgramOverviewState> {
  final ClassRepository _repo;

  ProgramOverviewBloc(this._repo) : super(ProgramOverviewInitial()) {
    on<LoadProgramClassesEvent>(_onLoad);
    on<AssignTeacherEvent>(_onAssign);
  }

  Future<void> _onLoad(
      LoadProgramClassesEvent event, Emitter<ProgramOverviewState> emit) async {
    emit(ProgramOverviewLoading());
    try {
      final classes = await _repo.getProgramClasses(
        termId: event.termId,
        subjectId: event.subjectId,
      );
      emit(ProgramOverviewLoaded(classes));
    } catch (e, st) {
      emit(ProgramOverviewError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onAssign(
      AssignTeacherEvent event, Emitter<ProgramOverviewState> emit) async {
    // Snapshot current data so we can restore it on error.
    final previousClasses = (state is ProgramOverviewLoaded)
        ? (state as ProgramOverviewLoaded).classes
        : <ClassModel>[];

    emit(ProgramOverviewAssigning(event.classId));
    try {
      await _repo.assignTeacher(event.classId, event.teacherUserId);
      // Re-fetch the full list so card data reflects the new assignment.
      final classes = await _repo.getProgramClasses(
        termId: event.termId,
        subjectId: event.subjectId,
      );
      emit(ProgramOverviewLoaded(classes));
    } catch (e, st) {
      emit(ProgramOverviewAssignError(
          getFriendlyErrorMessage(e, st), previousClasses));
    }
  }
}
