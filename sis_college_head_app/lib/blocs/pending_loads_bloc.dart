import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../models/setup_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/setup_repository.dart';
import '../utils/error_handler.dart';

// Events

abstract class PendingLoadsEvent {}

class PendingLoadsStarted extends PendingLoadsEvent {}

class PendingLoadsTermSelected extends PendingLoadsEvent {
  final String termId;
  PendingLoadsTermSelected(this.termId);
}

class PendingLoadsRefreshed extends PendingLoadsEvent {}

// State

class PendingLoadsState {
  final List<AcademicTermModel> terms;
  final String? selectedTermId;
  final bool isLoadingTerms;
  final bool isLoading;
  final List<PendingStudyLoadSummaryModel> pending;
  final String? errorMessage;

  const PendingLoadsState({
    this.terms = const [],
    this.selectedTermId,
    this.isLoadingTerms = false,
    this.isLoading = false,
    this.pending = const [],
    this.errorMessage,
  });

  AcademicTermModel? get selectedTerm {
    for (final t in terms) {
      if (t.termId == selectedTermId) return t;
    }
    return null;
  }

  int get studentCount => pending.length;

  int get subjectCount =>
      pending.fold<int>(0, (sum, p) => sum + p.pendingCount);

  int get overloadedCount => pending.where((p) => p.isOverloaded).length;

  PendingLoadsState copyWith({
    List<AcademicTermModel>? terms,
    String? selectedTermId,
    bool? isLoadingTerms,
    bool? isLoading,
    List<PendingStudyLoadSummaryModel>? pending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PendingLoadsState(
      terms: terms ?? this.terms,
      selectedTermId: selectedTermId ?? this.selectedTermId,
      isLoadingTerms: isLoadingTerms ?? this.isLoadingTerms,
      isLoading: isLoading ?? this.isLoading,
      pending: pending ?? this.pending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Bloc

class PendingLoadsBloc extends Bloc<PendingLoadsEvent, PendingLoadsState> {
  final ClassRepository _classRepo;
  final AcademicSetupRepository _setupRepo;

  PendingLoadsBloc(this._classRepo, this._setupRepo)
      : super(const PendingLoadsState()) {
    on<PendingLoadsStarted>(_onStarted);
    on<PendingLoadsTermSelected>(_onTermSelected);
    on<PendingLoadsRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
      PendingLoadsStarted event, Emitter<PendingLoadsState> emit) async {
    emit(state.copyWith(isLoadingTerms: true, clearError: true));
    try {
      final terms = await _setupRepo.getTerms();
      final active =
          terms.where((t) => t.isActive).firstOrNull ?? terms.firstOrNull;
      emit(state.copyWith(
        terms: terms,
        selectedTermId: active?.termId,
        isLoadingTerms: false,
      ));
      if (active != null) await _load(active.termId, emit);
    } catch (e, st) {
      emit(state.copyWith(
        isLoadingTerms: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onTermSelected(
      PendingLoadsTermSelected event, Emitter<PendingLoadsState> emit) async {
    if (event.termId == state.selectedTermId) return;
    emit(state.copyWith(selectedTermId: event.termId, clearError: true));
    await _load(event.termId, emit);
  }

  Future<void> _onRefreshed(
      PendingLoadsRefreshed event, Emitter<PendingLoadsState> emit) async {
    final termId = state.selectedTermId;
    if (termId == null) return;
    await _load(termId, emit);
  }

  Future<void> _load(String termId, Emitter<PendingLoadsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final pending = await _classRepo.getPendingSummary(termId);
      emit(state.copyWith(pending: pending, isLoading: false));
    } catch (e, st) {
      emit(state.copyWith(
        isLoading: false,
        pending: const [],
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }
}
