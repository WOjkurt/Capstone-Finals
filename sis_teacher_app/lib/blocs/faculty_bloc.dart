import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/grading_repository.dart';
import '../utils/error_handler.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class FacultyMember {
  final UserSearchResultModel teacher;
  final List<ClassModel> assignedClasses;

  const FacultyMember({
    required this.teacher,
    required this.assignedClasses,
  });

  String get userId => teacher.userId;
  String get firstname => teacher.firstname;
  String get lastname => teacher.lastname;
  String get fullName => teacher.fullName;
  String get email => teacher.email;
  int? get programId => teacher.programId;
  String? get programCode => teacher.programCode;
  int get classCount => assignedClasses.length;
  bool get hasClasses => classCount > 0;
  int get totalEnrolledStudents =>
      assignedClasses.fold<int>(0, (sum, c) => sum + c.enrolledCount);
}

// ── Events ────────────────────────────────────────────────────────────────────

abstract class FacultyEvent {}

class LoadFacultyEvent extends FacultyEvent {}

class AssignFacultyToClassEvent extends FacultyEvent {
  final String classId;
  final String? teacherUserId;

  AssignFacultyToClassEvent({
    required this.classId,
    this.teacherUserId,
  });
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class FacultyState {}

class FacultyInitial extends FacultyState {}

class FacultyLoading extends FacultyState {}

class FacultyLoaded extends FacultyState {
  final List<FacultyMember> faculty;
  final List<ClassModel> unassignedClasses;

  FacultyLoaded({
    required this.faculty,
    required this.unassignedClasses,
  });

  int get totalFaculty => faculty.length;
  int get teachersWithClassesCount => faculty.where((f) => f.hasClasses).length;
  int get teachersWithZeroClassesCount =>
      faculty.where((f) => !f.hasClasses).length;
}

class FacultyError extends FacultyState {
  final String message;

  FacultyError(this.message);
}

class FacultyAssigning extends FacultyState {
  final String? teacherUserId;
  final String classId;

  FacultyAssigning({
    this.teacherUserId,
    required this.classId,
  });
}

class FacultyAssignError extends FacultyState {
  final String message;
  final List<FacultyMember> previousFaculty;
  final List<ClassModel> previousUnassignedClasses;

  FacultyAssignError({
    required this.message,
    required this.previousFaculty,
    required this.previousUnassignedClasses,
  });
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

class FacultyBloc extends Bloc<FacultyEvent, FacultyState> {
  final UserSearchRepository _userSearchRepo;
  final ClassRepository _classRepo;

  FacultyBloc(this._userSearchRepo, this._classRepo) : super(FacultyInitial()) {
    on<LoadFacultyEvent>(_onLoad);
    on<AssignFacultyToClassEvent>(_onAssign);
  }

  Future<void> _onLoad(
      LoadFacultyEvent event, Emitter<FacultyState> emit) async {
    emit(FacultyLoading());
    try {
      final results = await Future.wait([
        _userSearchRepo.search(role: 3),
        _classRepo.getProgramClasses(),
      ]);

      final teachers = results[0] as List<UserSearchResultModel>;
      final classes = results[1] as List<ClassModel>;

      final Map<String, List<ClassModel>> classesByTeacherId = {};
      final List<ClassModel> unassigned = [];

      for (final c in classes) {
        if (c.userId != null && c.userId!.isNotEmpty) {
          classesByTeacherId.putIfAbsent(c.userId!, () => []).add(c);
        } else {
          unassigned.add(c);
        }
      }

      final facultyList = teachers.map((teacher) {
        final assigned = classesByTeacherId[teacher.userId] ?? const <ClassModel>[];
        return FacultyMember(
          teacher: teacher,
          assignedClasses: assigned,
        );
      }).toList();

      facultyList.sort((a, b) =>
          a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()));

      emit(FacultyLoaded(
        faculty: facultyList,
        unassignedClasses: unassigned,
      ));
    } catch (e, st) {
      emit(FacultyError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onAssign(
      AssignFacultyToClassEvent event, Emitter<FacultyState> emit) async {
    final prevFaculty = (state is FacultyLoaded)
        ? (state as FacultyLoaded).faculty
        : <FacultyMember>[];
    final prevUnassigned = (state is FacultyLoaded)
        ? (state as FacultyLoaded).unassignedClasses
        : <ClassModel>[];

    emit(FacultyAssigning(
      teacherUserId: event.teacherUserId,
      classId: event.classId,
    ));

    try {
      await _classRepo.assignTeacher(event.classId, event.teacherUserId);

      final results = await Future.wait([
        _userSearchRepo.search(role: 3),
        _classRepo.getProgramClasses(),
      ]);

      final teachers = results[0] as List<UserSearchResultModel>;
      final classes = results[1] as List<ClassModel>;

      final Map<String, List<ClassModel>> classesByTeacherId = {};
      final List<ClassModel> unassigned = [];

      for (final c in classes) {
        if (c.userId != null && c.userId!.isNotEmpty) {
          classesByTeacherId.putIfAbsent(c.userId!, () => []).add(c);
        } else {
          unassigned.add(c);
        }
      }

      final facultyList = teachers.map((teacher) {
        final assigned = classesByTeacherId[teacher.userId] ?? const <ClassModel>[];
        return FacultyMember(
          teacher: teacher,
          assignedClasses: assigned,
        );
      }).toList();

      facultyList.sort((a, b) =>
          a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()));

      emit(FacultyLoaded(
        faculty: facultyList,
        unassignedClasses: unassigned,
      ));
    } catch (e, st) {
      emit(FacultyAssignError(
        message: getFriendlyErrorMessage(e, st),
        previousFaculty: prevFaculty,
        previousUnassignedClasses: prevUnassigned,
      ));
    }
  }
}
