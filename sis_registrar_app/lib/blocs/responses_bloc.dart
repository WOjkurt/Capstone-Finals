import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';

// Events
abstract class ResponsesEvent {}

class LoadResponses extends ResponsesEvent {}

class ProcessResponseSubmitted extends ResponsesEvent {
  final String responseId;
  final int programId;
  final String termId;
  final EnrollmentFormModel form;
  final List<ContactModel> contacts;

  ProcessResponseSubmitted({
    required this.responseId,
    required this.programId,
    required this.termId,
    required this.form,
    required this.contacts,
  });
}

// States
abstract class ResponsesState {}

class ResponsesInitial extends ResponsesState {}

class ResponsesLoading extends ResponsesState {}

class ResponsesLoaded extends ResponsesState {
  final List<EnrollmentResponseModel> responses;
  final List<AcademicProgramModel> programs;
  final List<AcademicTermModel> terms;

  ResponsesLoaded({
    required this.responses,
    required this.programs,
    required this.terms,
  });
}

class ResponsesSubmitting extends ResponsesLoaded {
  ResponsesSubmitting({
    required super.responses,
    required super.programs,
    required super.terms,
  });
}

class ResponsesActionSuccess extends ResponsesLoaded {
  final String message;
  ResponsesActionSuccess({
    required this.message,
    required super.responses,
    required super.programs,
    required super.terms,
  });
}

class ResponsesError extends ResponsesState {
  final String message;
  final List<EnrollmentResponseModel>? responses;
  final List<AcademicProgramModel>? programs;
  final List<AcademicTermModel>? terms;

  ResponsesError(this.message, {this.responses, this.programs, this.terms});
}

// Bloc
class ResponsesBloc extends Bloc<ResponsesEvent, ResponsesState> {
  final EnrollmentRepository _enrollmentRepo;
  final AcademicSetupRepository _setupRepo;

  ResponsesBloc(this._enrollmentRepo, this._setupRepo)
      : super(ResponsesInitial()) {
    on<LoadResponses>(_onLoadResponses);
    on<ProcessResponseSubmitted>(_onProcessResponseSubmitted);
  }

  Future<void> _onLoadResponses(
      LoadResponses event, Emitter<ResponsesState> emit) async {
    emit(ResponsesLoading());
    try {
      final results = await Future.wait([
        _enrollmentRepo.getUnprocessedResponses(),
        _setupRepo.getPrograms(),
        _setupRepo.getTerms(),
      ]);

      emit(ResponsesLoaded(
        responses: results[0] as List<EnrollmentResponseModel>,
        programs: results[1] as List<AcademicProgramModel>,
        terms: results[2] as List<AcademicTermModel>,
      ));
    } catch (e) {
      emit(ResponsesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onProcessResponseSubmitted(
      ProcessResponseSubmitted event, Emitter<ResponsesState> emit) async {
    if (state is! ResponsesLoaded) return;
    final current = state as ResponsesLoaded;

    emit(ResponsesSubmitting(
      responses: current.responses,
      programs: current.programs,
      terms: current.terms,
    ));

    try {
      await _enrollmentRepo.createApplication(
        responseId: event.responseId,
        programId: event.programId,
        termId: event.termId,
        form: event.form,
        contacts: event.contacts,
      );

      // Reload responses
      final updatedResponses = await _enrollmentRepo.getUnprocessedResponses();
      emit(ResponsesActionSuccess(
        message: 'Response successfully converted into an Enrollment Application!',
        responses: updatedResponses,
        programs: current.programs,
        terms: current.terms,
      ));
    } catch (e) {
      emit(ResponsesError(
        e.toString().replaceFirst('Exception: ', ''),
        responses: current.responses,
        programs: current.programs,
        terms: current.terms,
      ));
    }
  }
}
