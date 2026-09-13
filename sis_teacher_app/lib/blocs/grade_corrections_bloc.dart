import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../repositories/grading_repository.dart';
import '../utils/error_handler.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class GradeCorrectionsEvent {}

/// Trigger a (re)load of the authenticated teacher's correction history.
class LoadMyCorrectionsEvent extends GradeCorrectionsEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class GradeCorrectionsState {}

class GradeCorrectionsInitial extends GradeCorrectionsState {}

class GradeCorrectionsLoading extends GradeCorrectionsState {}

class GradeCorrectionsLoaded extends GradeCorrectionsState {
  final List<GradeCorrectionModel> corrections;

  GradeCorrectionsLoaded(this.corrections);
}

class GradeCorrectionsError extends GradeCorrectionsState {
  final String message;

  GradeCorrectionsError(this.message);
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

class GradeCorrectionsBloc
    extends Bloc<GradeCorrectionsEvent, GradeCorrectionsState> {
  final GradeCorrectionRepository _repo;

  GradeCorrectionsBloc(this._repo) : super(GradeCorrectionsInitial()) {
    on<LoadMyCorrectionsEvent>(_onLoad);
  }

  Future<void> _onLoad(
      LoadMyCorrectionsEvent event, Emitter<GradeCorrectionsState> emit) async {
    emit(GradeCorrectionsLoading());
    try {
      final corrections = await _repo.getMyCorrections();
      emit(GradeCorrectionsLoaded(corrections));
    } catch (e, st) {
      emit(GradeCorrectionsError(getFriendlyErrorMessage(e, st)));
    }
  }
}
