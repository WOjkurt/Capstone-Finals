import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../repositories/grading_repository.dart';

// Events
abstract class CorrectionsEvent {}

class LoadCorrections extends CorrectionsEvent {}

class ApproveCorrectionEvent extends CorrectionsEvent {
  final String id;
  ApproveCorrectionEvent(this.id);
}

class RejectCorrectionEvent extends CorrectionsEvent {
  final String id;
  final String? reason;
  RejectCorrectionEvent(this.id, {this.reason});
}

// States
abstract class CorrectionsState {}

class CorrectionsInitial extends CorrectionsState {}

class CorrectionsLoading extends CorrectionsState {}

class CorrectionsLoaded extends CorrectionsState {
  final List<GradeCorrectionModel> corrections;
  final String? processingId;

  CorrectionsLoaded({
    required this.corrections,
    this.processingId,
  });

  CorrectionsLoaded copyWith({
    List<GradeCorrectionModel>? corrections,
    String? processingId,
    bool clearProcessing = false,
  }) {
    return CorrectionsLoaded(
      corrections: corrections ?? this.corrections,
      processingId: clearProcessing
          ? null
          : (processingId ?? this.processingId),
    );
  }
}

class CorrectionsActionSuccess extends CorrectionsLoaded {
  final String message;
  CorrectionsActionSuccess({
    required this.message,
    required super.corrections,
  });
}

class CorrectionsError extends CorrectionsState {
  final String message;
  final List<GradeCorrectionModel>? corrections;

  CorrectionsError(this.message, {this.corrections});
}

// Bloc
class CorrectionsBloc extends Bloc<CorrectionsEvent, CorrectionsState> {
  final GradeCorrectionRepository _correctionRepo;

  CorrectionsBloc(this._correctionRepo) : super(CorrectionsInitial()) {
    on<LoadCorrections>(_onLoadCorrections);
    on<ApproveCorrectionEvent>(_onApproveCorrection);
    on<RejectCorrectionEvent>(_onRejectCorrection);
  }

  Future<void> _onLoadCorrections(
      LoadCorrections event, Emitter<CorrectionsState> emit) async {
    emit(CorrectionsLoading());
    try {
      final list = await _correctionRepo.getPendingCorrections();
      emit(CorrectionsLoaded(corrections: list));
    } catch (e) {
      emit(CorrectionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onApproveCorrection(
      ApproveCorrectionEvent event, Emitter<CorrectionsState> emit) async {
    if (state is! CorrectionsLoaded) return;
    final current = state as CorrectionsLoaded;

    emit(current.copyWith(processingId: event.id));
    try {
      await _correctionRepo.approveCorrection(event.id);
      final updated = await _correctionRepo.getPendingCorrections();
      emit(CorrectionsActionSuccess(
        message: 'Grade correction request approved successfully!',
        corrections: updated,
      ));
    } catch (e) {
      emit(current.copyWith(clearProcessing: true));
      emit(CorrectionsError(
        e.toString().replaceFirst('Exception: ', ''),
        corrections: current.corrections,
      ));
    }
  }

  Future<void> _onRejectCorrection(
      RejectCorrectionEvent event, Emitter<CorrectionsState> emit) async {
    if (state is! CorrectionsLoaded) return;
    final current = state as CorrectionsLoaded;

    emit(current.copyWith(processingId: event.id));
    try {
      await _correctionRepo.rejectCorrection(event.id, reason: event.reason);
      final updated = await _correctionRepo.getPendingCorrections();
      emit(CorrectionsActionSuccess(
        message: 'Grade correction request rejected.',
        corrections: updated,
      ));
    } catch (e) {
      emit(current.copyWith(clearProcessing: true));
      emit(CorrectionsError(
        e.toString().replaceFirst('Exception: ', ''),
        corrections: current.corrections,
      ));
    }
  }
}
