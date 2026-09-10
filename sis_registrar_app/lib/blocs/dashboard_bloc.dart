import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/enrollment_repository.dart';
import '../repositories/grading_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class DashboardEvent {}

class LoadDashboardData extends DashboardEvent {}

// States
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int unprocessedResponsesCount;
  final int pendingApplicationsCount;
  final int approvedApplicationsCount;
  final int pendingCorrectionsCount;

  DashboardLoaded({
    required this.unprocessedResponsesCount,
    required this.pendingApplicationsCount,
    required this.approvedApplicationsCount,
    required this.pendingCorrectionsCount,
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

// Bloc
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final EnrollmentRepository _enrollmentRepo;
  final GradeCorrectionRepository _correctionRepo;

  DashboardBloc(this._enrollmentRepo, this._correctionRepo)
      : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
  }

  Future<void> _onLoadDashboardData(
      LoadDashboardData event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final results = await Future.wait([
        _enrollmentRepo.getUnprocessedResponses(),
        _enrollmentRepo.getApplications('pending'),
        _enrollmentRepo.getApplications('approved'),
        _correctionRepo.getPendingCorrections(),
      ]);

      final unprocessed = results[0] as List;
      final pendingApps = results[1] as List;
      final approvedApps = results[2] as List;
      final pendingCorrections = results[3] as List;

      emit(DashboardLoaded(
        unprocessedResponsesCount: unprocessed.length,
        pendingApplicationsCount: pendingApps.length,
        approvedApplicationsCount: approvedApps.length,
        pendingCorrectionsCount: pendingCorrections.length,
      ));
    } catch (e, st) {
      emit(DashboardError(getFriendlyErrorMessage(e, st)));
    }
  }
}
