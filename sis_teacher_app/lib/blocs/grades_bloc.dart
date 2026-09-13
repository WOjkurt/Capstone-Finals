import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/grades_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class GradesEvent {}

class LoadClassGradesSheetEvent extends GradesEvent {
  final ClassModel classItem;

  LoadClassGradesSheetEvent(this.classItem);
}

class SubmitSingleGradeRowEvent extends GradesEvent {
  final String studyLoadId;
  final double? midtermGrade;
  final double? finalGrade;
  final String studentName;

  SubmitSingleGradeRowEvent({
    required this.studyLoadId,
    this.midtermGrade,
    this.finalGrade,
    required this.studentName,
  });
}

class SubmitBatchGradesEvent extends GradesEvent {
  final SubmitGradeBatchModel batch;

  SubmitBatchGradesEvent(this.batch);
}

class ClearGradeSheetFeedbackEvent extends GradesEvent {}

// States
abstract class GradesState {}

class GradesInitial extends GradesState {}

class GradesSheetLoading extends GradesState {}

class GradesSheetLoaded extends GradesState {
  final ClassModel classItem;
  final List<ClassRosterItemModel> roster;
  final Map<String, GradeModel> grades;
  final String? savingRowStudyLoadId;
  final bool isSubmittingBatch;
  final GradeBatchResultModel? lastBatchResult;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;

  GradesSheetLoaded({
    required this.classItem,
    required this.roster,
    required this.grades,
    this.savingRowStudyLoadId,
    this.isSubmittingBatch = false,
    this.lastBatchResult,
    this.actionSuccessMessage,
    this.actionErrorMessage,
  });

  GradesSheetLoaded copyWith({
    ClassModel? classItem,
    List<ClassRosterItemModel>? roster,
    Map<String, GradeModel>? grades,
    String? savingRowStudyLoadId,
    bool clearSavingRow = false,
    bool? isSubmittingBatch,
    GradeBatchResultModel? lastBatchResult,
    bool clearBatchResult = false,
    String? actionSuccessMessage,
    String? actionErrorMessage,
    bool clearFeedback = false,
  }) {
    return GradesSheetLoaded(
      classItem: classItem ?? this.classItem,
      roster: roster ?? this.roster,
      grades: grades ?? this.grades,
      savingRowStudyLoadId: clearSavingRow
          ? null
          : (savingRowStudyLoadId ?? this.savingRowStudyLoadId),
      isSubmittingBatch: isSubmittingBatch ?? this.isSubmittingBatch,
      lastBatchResult: clearBatchResult
          ? null
          : (lastBatchResult ?? this.lastBatchResult),
      actionSuccessMessage: clearFeedback
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
      actionErrorMessage: clearFeedback
          ? null
          : (actionErrorMessage ?? this.actionErrorMessage),
    );
  }
}

class GradesSheetError extends GradesState {
  final String message;

  GradesSheetError(this.message);
}

// Bloc
class GradesBloc extends Bloc<GradesEvent, GradesState> {
  final ClassRepository _classRepo;
  final GradesRepository _gradesRepo;

  GradesBloc(this._classRepo, this._gradesRepo) : super(GradesInitial()) {
    on<LoadClassGradesSheetEvent>(_onLoadClassGradesSheet);
    on<SubmitSingleGradeRowEvent>(_onSubmitSingleGradeRow);
    on<SubmitBatchGradesEvent>(_onSubmitBatchGrades);
    on<ClearGradeSheetFeedbackEvent>(_onClearFeedback);
  }

  Future<void> _onLoadClassGradesSheet(
      LoadClassGradesSheetEvent event, Emitter<GradesState> emit) async {
    emit(GradesSheetLoading());
    try {
      final futures = await Future.wait([
        _classRepo.getClassRoster(event.classItem.classId),
        _gradesRepo.getClassGrades(event.classItem.classId),
      ]);

      final roster = futures[0] as List<ClassRosterItemModel>;
      final gradesList = futures[1] as List<GradeModel>;

      final gradesMap = <String, GradeModel>{
        for (final g in gradesList) g.studyLoadId: g,
      };

      emit(GradesSheetLoaded(
        classItem: event.classItem,
        roster: roster,
        grades: gradesMap,
      ));
    } catch (e, st) {
      emit(GradesSheetError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onSubmitSingleGradeRow(
      SubmitSingleGradeRowEvent event, Emitter<GradesState> emit) async {
    if (state is! GradesSheetLoaded) return;
    final current = state as GradesSheetLoaded;

    emit(current.copyWith(
      savingRowStudyLoadId: event.studyLoadId,
      clearFeedback: true,
      clearBatchResult: true,
    ));

    try {
      final savedGrade = await _gradesRepo.submitGrade(
        event.studyLoadId,
        midtermGrade: event.midtermGrade,
        finalGrade: event.finalGrade,
      );

      final newGrades = Map<String, GradeModel>.from(current.grades);
      newGrades[event.studyLoadId] = savedGrade;

      emit(current.copyWith(
        grades: newGrades,
        clearSavingRow: true,
        actionSuccessMessage: 'Saved grade for ${event.studentName}.',
      ));
    } catch (e, st) {
      emit(current.copyWith(
        clearSavingRow: true,
        actionErrorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onSubmitBatchGrades(
      SubmitBatchGradesEvent event, Emitter<GradesState> emit) async {
    if (state is! GradesSheetLoaded) return;
    final current = state as GradesSheetLoaded;

    emit(current.copyWith(
      isSubmittingBatch: true,
      clearFeedback: true,
      clearBatchResult: true,
    ));

    try {
      final result = await _gradesRepo.submitGradeBatch(event.batch);

      final newGrades = Map<String, GradeModel>.from(current.grades);
      for (final g in result.succeeded) {
        newGrades[g.studyLoadId] = g;
      }

      emit(current.copyWith(
        grades: newGrades,
        isSubmittingBatch: false,
        lastBatchResult: result,
      ));
    } catch (e, st) {
      emit(current.copyWith(
        isSubmittingBatch: false,
        actionErrorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  void _onClearFeedback(
      ClearGradeSheetFeedbackEvent event, Emitter<GradesState> emit) {
    if (state is! GradesSheetLoaded) return;
    final current = state as GradesSheetLoaded;
    emit(current.copyWith(
      clearFeedback: true,
      clearBatchResult: true,
    ));
  }
}
