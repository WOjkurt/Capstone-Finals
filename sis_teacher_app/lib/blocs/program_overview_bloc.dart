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

// ── Bloc ─────────────────────────────────────────────────────────────────────

class ProgramOverviewBloc
    extends Bloc<ProgramOverviewEvent, ProgramOverviewState> {
  final ClassRepository _repo;

  ProgramOverviewBloc(this._repo) : super(ProgramOverviewInitial()) {
    on<LoadProgramClassesEvent>(_onLoad);
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
}
