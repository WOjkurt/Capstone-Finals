import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class LinkAccountsEvent {}

class LoadApprovedApplications extends LinkAccountsEvent {}

class LinkAccountSubmitted extends LinkAccountsEvent {
  final String applicationId;
  final String email;
  LinkAccountSubmitted(this.applicationId, this.email);
}

// States
abstract class LinkAccountsState {}

class LinkAccountsInitial extends LinkAccountsState {}

class LinkAccountsLoading extends LinkAccountsState {}

class LinkAccountsLoaded extends LinkAccountsState {
  final List<EnrollmentApplicationModel> applications;
  final List<AcademicProgramModel> programs;
  final String? linkingApplicationId;

  LinkAccountsLoaded({
    required this.applications,
    this.programs = const [],
    this.linkingApplicationId,
  });

  LinkAccountsLoaded copyWith({
    List<EnrollmentApplicationModel>? applications,
    List<AcademicProgramModel>? programs,
    String? linkingApplicationId,
    bool clearLinking = false,
  }) {
    return LinkAccountsLoaded(
      applications: applications ?? this.applications,
      programs: programs ?? this.programs,
      linkingApplicationId: clearLinking
          ? null
          : (linkingApplicationId ?? this.linkingApplicationId),
    );
  }
}

class LinkAccountsActionSuccess extends LinkAccountsLoaded {
  final String message;
  LinkAccountsActionSuccess({
    required this.message,
    required super.applications,
    super.programs,
  });
}

class LinkAccountsError extends LinkAccountsState {
  final String message;
  final List<EnrollmentApplicationModel>? applications;
  final List<AcademicProgramModel>? programs;

  LinkAccountsError(this.message, {this.applications, this.programs});
}

// Bloc
class LinkAccountsBloc extends Bloc<LinkAccountsEvent, LinkAccountsState> {
  final EnrollmentRepository _enrollmentRepo;
  final AcademicSetupRepository _setupRepo;

  LinkAccountsBloc(this._enrollmentRepo, this._setupRepo)
      : super(LinkAccountsInitial()) {
    on<LoadApprovedApplications>(_onLoadApprovedApplications);
    on<LinkAccountSubmitted>(_onLinkAccountSubmitted);
  }

  Future<void> _onLoadApprovedApplications(
      LoadApprovedApplications event, Emitter<LinkAccountsState> emit) async {
    emit(LinkAccountsLoading());
    try {
      final results = await Future.wait([
        _enrollmentRepo.getApprovedApplications(),
        _setupRepo.getPrograms(),
      ]);

      emit(LinkAccountsLoaded(
        applications: results[0] as List<EnrollmentApplicationModel>,
        programs: results[1] as List<AcademicProgramModel>,
      ));
    } catch (e, st) {
      emit(LinkAccountsError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onLinkAccountSubmitted(
      LinkAccountSubmitted event, Emitter<LinkAccountsState> emit) async {
    if (state is! LinkAccountsLoaded) return;
    final current = state as LinkAccountsLoaded;

    emit(current.copyWith(linkingApplicationId: event.applicationId));
    try {
      final result =
          await _enrollmentRepo.linkAccount(event.applicationId, event.email);
      final studentId = result['studentID'] ?? '';

      // Reload approved applications list
      final updatedList = await _enrollmentRepo.getApprovedApplications();
      emit(LinkAccountsActionSuccess(
        message:
            'Account linked successfully! Assigned Student ID: $studentId',
        applications: updatedList,
        programs: current.programs,
      ));
    } catch (e, st) {
      final errorMsg = getFriendlyErrorMessage(e, st);
      emit(current.copyWith(clearLinking: true));
      emit(LinkAccountsError(
        errorMsg,
        applications: current.applications,
        programs: current.programs,
      ));
    }
  }
}
