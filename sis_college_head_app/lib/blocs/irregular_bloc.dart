import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// Events

abstract class IrregularEvent {}

class IrregularStarted extends IrregularEvent {}

class IrregularProgramFiltered extends IrregularEvent {
  /// null means every program.
  final String? programCode;
  IrregularProgramFiltered(this.programCode);
}

// State

class IrregularState {
  final bool isLoading;
  final List<IrregularStudentModel> students;
  final String? programCode;
  final String? errorMessage;

  const IrregularState({
    this.isLoading = false,
    this.students = const [],
    this.programCode,
    this.errorMessage,
  });

  /// Programs present in the data, for the filter.
  List<String> get programCodes {
    final codes = <String>{
      for (final s in students)
        if (s.programCode != null && s.programCode!.isNotEmpty) s.programCode!,
    }.toList()
      ..sort();
    return codes;
  }

  List<IrregularStudentModel> get visible => programCode == null
      ? students
      : students.where((s) => s.programCode == programCode).toList();

  /// The ones the Registrar could return to regular standing now.
  List<IrregularStudentModel> get ready =>
      visible.where((s) => s.readyToBeRegular).toList();

  List<IrregularStudentModel> get stillShort =>
      visible.where((s) => !s.readyToBeRegular).toList();

  IrregularState copyWith({
    bool? isLoading,
    List<IrregularStudentModel>? students,
    String? programCode,
    bool clearProgram = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return IrregularState(
      isLoading: isLoading ?? this.isLoading,
      students: students ?? this.students,
      programCode: clearProgram ? null : (programCode ?? this.programCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Bloc

class IrregularBloc extends Bloc<IrregularEvent, IrregularState> {
  final StudentRepository _students;

  IrregularBloc(this._students) : super(const IrregularState()) {
    on<IrregularStarted>(_onStarted);
    on<IrregularProgramFiltered>(_onFiltered);
  }

  Future<void> _onStarted(
      IrregularStarted event, Emitter<IrregularState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final list = await _students.getIrregularStudents();
      list.sort((a, b) =>
          a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));
      emit(state.copyWith(students: list, isLoading: false));
    } catch (e, st) {
      emit(state.copyWith(
        isLoading: false,
        students: const [],
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  void _onFiltered(IrregularProgramFiltered event, Emitter<IrregularState> emit) {
    emit(event.programCode == null
        ? state.copyWith(clearProgram: true)
        : state.copyWith(programCode: event.programCode));
  }
}
