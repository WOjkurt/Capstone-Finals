import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ClearanceEvent {}

class LoadClearancesEvent extends ClearanceEvent {
  final String userId;
  final bool refresh;

  LoadClearancesEvent({
    required this.userId,
    this.refresh = false,
  });
}

// ── States ───────────────────────────────────────────────────────────────────

abstract class ClearanceState {}

class ClearanceInitial extends ClearanceState {}

class ClearanceLoading extends ClearanceState {}

class ClearanceLoaded extends ClearanceState {
  final List<GradeClearanceModel> clearances;

  ClearanceLoaded({
    required this.clearances,
  });

  int get totalTerms => clearances.length;

  int get clearedCount => clearances.where((c) => c.isCleared).length;

  int get withheldCount => clearances.where((c) => !c.isCleared).length;
}

class ClearanceError extends ClearanceState {
  final String message;

  ClearanceError(this.message);
}

// ── BLoC ────────────────────────────────────────────────────────────────────

class ClearanceBloc extends Bloc<ClearanceEvent, ClearanceState> {
  final StudentRepository _repository;

  ClearanceBloc(this._repository) : super(ClearanceInitial()) {
    on<LoadClearancesEvent>(_onLoadClearances);
  }

  Future<void> _onLoadClearances(
    LoadClearancesEvent event,
    Emitter<ClearanceState> emit,
  ) async {
    if (!event.refresh && state is! ClearanceLoaded) {
      emit(ClearanceLoading());
    }

    try {
      final list = await _repository.getGradeClearances(event.userId);

      // Backend orders ascending (older terms first); reverse so most recent is first
      final recentFirst = list.reversed.toList();

      emit(ClearanceLoaded(clearances: recentFirst));
    } catch (e, st) {
      emit(ClearanceError(getFriendlyErrorMessage(e, st)));
    }
  }
}
