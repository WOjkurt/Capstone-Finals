import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';

// Events
abstract class ApplicationsEvent {}

class LoadApplications extends ApplicationsEvent {
  final String? statusFilter; // null, 'pending', 'approved', 'rejected', 'active'
  LoadApplications({this.statusFilter});
}

class ViewApplicationDetail extends ApplicationsEvent {
  final String applicationId;
  ViewApplicationDetail(this.applicationId);
}

class ClearApplicationDetail extends ApplicationsEvent {}

class ApproveApplicationEvent extends ApplicationsEvent {
  final String applicationId;
  final int? yearLevel;
  ApproveApplicationEvent(this.applicationId, {this.yearLevel});
}

class RejectApplicationEvent extends ApplicationsEvent {
  final String applicationId;
  final String? reason;
  RejectApplicationEvent(this.applicationId, {this.reason});
}

// States
abstract class ApplicationsState {}

class ApplicationsInitial extends ApplicationsState {}

class ApplicationsLoading extends ApplicationsState {}

class ApplicationsLoaded extends ApplicationsState {
  final List<EnrollmentApplicationModel> applications;
  final String? statusFilter;
  final EnrollmentApplicationModel? selectedDetail;
  final bool isDetailLoading;
  final bool isActionInProgress;
  final List<AcademicProgramModel> programs;
  final List<AcademicTermModel> terms;

  ApplicationsLoaded({
    required this.applications,
    this.statusFilter,
    this.selectedDetail,
    this.isDetailLoading = false,
    this.isActionInProgress = false,
    this.programs = const [],
    this.terms = const [],
  });

  ApplicationsLoaded copyWith({
    List<EnrollmentApplicationModel>? applications,
    String? statusFilter,
    EnrollmentApplicationModel? selectedDetail,
    bool? clearSelectedDetail,
    bool? isDetailLoading,
    bool? isActionInProgress,
    List<AcademicProgramModel>? programs,
    List<AcademicTermModel>? terms,
  }) {
    return ApplicationsLoaded(
      applications: applications ?? this.applications,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedDetail: clearSelectedDetail == true
          ? null
          : (selectedDetail ?? this.selectedDetail),
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      programs: programs ?? this.programs,
      terms: terms ?? this.terms,
    );
  }
}

class ApplicationsActionSuccess extends ApplicationsLoaded {
  final String message;
  ApplicationsActionSuccess({
    required this.message,
    required super.applications,
    super.statusFilter,
    super.selectedDetail,
    super.programs,
    super.terms,
  });
}

class ApplicationsError extends ApplicationsState {
  final String message;
  final List<EnrollmentApplicationModel>? applications;
  final String? statusFilter;
  final List<AcademicProgramModel>? programs;
  final List<AcademicTermModel>? terms;

  ApplicationsError(this.message,
      {this.applications, this.statusFilter, this.programs, this.terms});
}

// Bloc
class ApplicationsBloc extends Bloc<ApplicationsEvent, ApplicationsState> {
  final EnrollmentRepository _enrollmentRepo;
  final AcademicSetupRepository _setupRepo;

  ApplicationsBloc(this._enrollmentRepo, this._setupRepo)
      : super(ApplicationsInitial()) {
    on<LoadApplications>(_onLoadApplications);
    on<ViewApplicationDetail>(_onViewApplicationDetail);
    on<ClearApplicationDetail>(_onClearApplicationDetail);
    on<ApproveApplicationEvent>(_onApproveApplication);
    on<RejectApplicationEvent>(_onRejectApplication);
  }

  Future<void> _onLoadApplications(
      LoadApplications event, Emitter<ApplicationsState> emit) async {
    emit(ApplicationsLoading());
    try {
      final results = await Future.wait([
        _enrollmentRepo.getApplications(event.statusFilter),
        _setupRepo.getPrograms(),
        _setupRepo.getTerms(),
      ]);

      emit(ApplicationsLoaded(
        applications: results[0] as List<EnrollmentApplicationModel>,
        statusFilter: event.statusFilter,
        programs: results[1] as List<AcademicProgramModel>,
        terms: results[2] as List<AcademicTermModel>,
      ));
    } catch (e) {
      emit(ApplicationsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onViewApplicationDetail(
      ViewApplicationDetail event, Emitter<ApplicationsState> emit) async {
    if (state is! ApplicationsLoaded) return;
    final current = state as ApplicationsLoaded;

    emit(current.copyWith(isDetailLoading: true));
    try {
      final detail = await _enrollmentRepo.getApplicationById(event.applicationId);
      emit(current.copyWith(selectedDetail: detail, isDetailLoading: false));
    } catch (e) {
      emit(current.copyWith(isDetailLoading: false));
    }
  }

  void _onClearApplicationDetail(
      ClearApplicationDetail event, Emitter<ApplicationsState> emit) {
    if (state is! ApplicationsLoaded) return;
    emit((state as ApplicationsLoaded).copyWith(clearSelectedDetail: true));
  }

  Future<void> _onApproveApplication(
      ApproveApplicationEvent event, Emitter<ApplicationsState> emit) async {
    if (state is! ApplicationsLoaded) return;
    final current = state as ApplicationsLoaded;

    emit(current.copyWith(isActionInProgress: true));
    try {
      await _enrollmentRepo.approveApplication(event.applicationId,
          yearLevel: event.yearLevel);
      final updatedList =
          await _enrollmentRepo.getApplications(current.statusFilter);
      emit(ApplicationsActionSuccess(
        message: 'Application approved successfully.',
        applications: updatedList,
        statusFilter: current.statusFilter,
        programs: current.programs,
        terms: current.terms,
      ));
    } catch (e) {
      emit(current.copyWith(isActionInProgress: false));
      emit(ApplicationsError(
        e.toString().replaceFirst('Exception: ', ''),
        applications: current.applications,
        statusFilter: current.statusFilter,
        programs: current.programs,
        terms: current.terms,
      ));
    }
  }

  Future<void> _onRejectApplication(
      RejectApplicationEvent event, Emitter<ApplicationsState> emit) async {
    if (state is! ApplicationsLoaded) return;
    final current = state as ApplicationsLoaded;

    emit(current.copyWith(isActionInProgress: true));
    try {
      await _enrollmentRepo.rejectApplication(event.applicationId,
          reason: event.reason);
      final updatedList =
          await _enrollmentRepo.getApplications(current.statusFilter);
      emit(ApplicationsActionSuccess(
        message: 'Application rejected successfully.',
        applications: updatedList,
        statusFilter: current.statusFilter,
        programs: current.programs,
        terms: current.terms,
      ));
    } catch (e) {
      emit(current.copyWith(isActionInProgress: false));
      emit(ApplicationsError(
        e.toString().replaceFirst('Exception: ', ''),
        applications: current.applications,
        statusFilter: current.statusFilter,
        programs: current.programs,
        terms: current.terms,
      ));
    }
  }
}
