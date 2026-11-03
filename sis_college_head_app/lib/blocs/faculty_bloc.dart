import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/setup_repository.dart';
import '../repositories/teacher_repository.dart';
import '../utils/error_handler.dart';

class FacultyMember {
  final UserSearchResultModel teacher;
  final List<ClassModel> classes;

  const FacultyMember({required this.teacher, required this.classes});
}

// Events
abstract class FacultyEvent {}

class FacultyStarted extends FacultyEvent {}

class FacultyTermSelected extends FacultyEvent {
  final String termId;
  FacultyTermSelected(this.termId);
}

/// [programId] null means all programs.
class FacultyProgramSelected extends FacultyEvent {
  final int? programId;
  FacultyProgramSelected(this.programId);
}

class FacultyAssignRequested extends FacultyEvent {
  final String classId;
  final String? teacherUserId;
  FacultyAssignRequested({required this.classId, this.teacherUserId});
}

// State
class FacultyState {
  final List<AcademicTermModel> terms;
  final List<AcademicProgramModel> programs;
  final String? selectedTermId;
  final int? selectedProgramId;
  final List<UserSearchResultModel> teachers;
  final List<ClassModel> classes;
  final bool isLoading;
  final bool isAssigning;
  final String? errorMessage;
  final String? successMessage;

  const FacultyState({
    this.terms = const [],
    this.programs = const [],
    this.selectedTermId,
    this.selectedProgramId,
    this.teachers = const [],
    this.classes = const [],
    this.isLoading = false,
    this.isAssigning = false,
    this.errorMessage,
    this.successMessage,
  });

  List<ClassModel> get filteredClasses => selectedProgramId == null
      ? classes
      : classes.where((c) => c.programId == selectedProgramId).toList();

  /// Classes with no teacher, minor subjects first.
  List<ClassModel> get unassignedClasses {
    final list = filteredClasses
        .where((c) => c.userId == null || c.userId!.isEmpty)
        .toList();
    list.sort((a, b) {
      if (a.isMinor != b.isMinor) return a.isMinor ? -1 : 1;
      return (a.subjectCode ?? '').compareTo(b.subjectCode ?? '');
    });
    return list;
  }

  /// Teachers with their classes in the current filter. With a program
  /// selected, shows teachers of that program plus anyone teaching in it.
  List<FacultyMember> get faculty {
    final byTeacher = <String, List<ClassModel>>{};
    for (final c in filteredClasses) {
      if (c.userId != null && c.userId!.isNotEmpty) {
        byTeacher.putIfAbsent(c.userId!, () => []).add(c);
      }
    }
    final members = teachers
        .where((t) =>
            selectedProgramId == null ||
            t.programId == selectedProgramId ||
            byTeacher.containsKey(t.userId))
        .map((t) => FacultyMember(
              teacher: t,
              classes: byTeacher[t.userId] ?? const <ClassModel>[],
            ))
        .toList();
    members.sort((a, b) => a.teacher.lastname
        .toLowerCase()
        .compareTo(b.teacher.lastname.toLowerCase()));
    return members;
  }

  String programCodeFor(int? programId) {
    if (programId == null) return 'No program';
    for (final p in programs) {
      if (p.programId == programId) return p.programCode;
    }
    return 'Unknown';
  }

  FacultyState copyWith({
    List<AcademicTermModel>? terms,
    List<AcademicProgramModel>? programs,
    String? selectedTermId,
    int? selectedProgramId,
    bool clearProgram = false,
    List<UserSearchResultModel>? teachers,
    List<ClassModel>? classes,
    bool? isLoading,
    bool? isAssigning,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return FacultyState(
      terms: terms ?? this.terms,
      programs: programs ?? this.programs,
      selectedTermId: selectedTermId ?? this.selectedTermId,
      selectedProgramId:
          clearProgram ? null : (selectedProgramId ?? this.selectedProgramId),
      teachers: teachers ?? this.teachers,
      classes: classes ?? this.classes,
      isLoading: isLoading ?? this.isLoading,
      isAssigning: isAssigning ?? this.isAssigning,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

// Bloc
class FacultyBloc extends Bloc<FacultyEvent, FacultyState> {
  final TeacherRepository _teacherRepo;
  final ClassRepository _classRepo;
  final AcademicSetupRepository _setupRepo;

  FacultyBloc(this._teacherRepo, this._classRepo, this._setupRepo)
      : super(const FacultyState()) {
    on<FacultyStarted>(_onStarted);
    on<FacultyTermSelected>(_onTermSelected);
    on<FacultyProgramSelected>(_onProgramSelected);
    on<FacultyAssignRequested>(_onAssignRequested);
  }

  Future<void> _onStarted(
      FacultyStarted event, Emitter<FacultyState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    try {
      final results = await Future.wait([
        _setupRepo.getTerms(),
        _setupRepo.getPrograms(),
        _teacherRepo.searchTeachers(''),
      ]);
      final terms = results[0] as List<AcademicTermModel>;
      final programs = results[1] as List<AcademicProgramModel>;
      final teachers = results[2] as List<UserSearchResultModel>;

      // Newest first; default to the active term, else the newest one.
      terms.sort((a, b) {
        final byYear = b.schoolYear.compareTo(a.schoolYear);
        return byYear != 0 ? byYear : b.semester.compareTo(a.semester);
      });
      String? termId;
      for (final t in terms) {
        if (t.isActive) termId = t.termId;
      }
      termId ??= terms.isNotEmpty ? terms.first.termId : null;

      final classes = termId == null
          ? <ClassModel>[]
          : await _classRepo.getClasses(termId: termId);

      emit(state.copyWith(
        terms: terms,
        programs: programs,
        teachers: teachers,
        selectedTermId: termId,
        classes: classes,
        isLoading: false,
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onTermSelected(
      FacultyTermSelected event, Emitter<FacultyState> emit) async {
    emit(state.copyWith(
        selectedTermId: event.termId, isLoading: true, clearMessages: true));
    try {
      final classes = await _classRepo.getClasses(termId: event.termId);
      emit(state.copyWith(classes: classes, isLoading: false));
    } catch (e, st) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  void _onProgramSelected(
      FacultyProgramSelected event, Emitter<FacultyState> emit) {
    emit(event.programId == null
        ? state.copyWith(clearProgram: true, clearMessages: true)
        : state.copyWith(
            selectedProgramId: event.programId, clearMessages: true));
  }

  Future<void> _onAssignRequested(
      FacultyAssignRequested event, Emitter<FacultyState> emit) async {
    final termId = state.selectedTermId;
    emit(state.copyWith(isAssigning: true, clearMessages: true));
    try {
      await _classRepo.assignTeacher(event.classId, event.teacherUserId);
      final classes = termId == null
          ? state.classes
          : await _classRepo.getClasses(termId: termId);
      emit(state.copyWith(
        classes: classes,
        isAssigning: false,
        successMessage: event.teacherUserId == null
            ? 'Teacher removed from the class.'
            : 'Teacher assigned.',
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isAssigning: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }
}
