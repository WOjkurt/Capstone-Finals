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

  /// Lecture + lab units across the assigned classes. Classes do not carry
  /// units, so this is joined from the subject list; 0 when a subject is
  /// missing from that list.
  final double totalUnits;

  const FacultyMember({
    required this.teacher,
    required this.assignedClasses,
    this.totalUnits = 0,
  });

  /// '0', '3' or '4.5' — trailing '.0' is noise in a workload column.
  String get unitsLabel =>
      totalUnits.toStringAsFixed(totalUnits.truncateToDouble() == totalUnits ? 0 : 1);

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

/// One teacher's classes plus the matching unit totals, shared by the load and
/// the post-assignment reload.
class _FacultyGrouping {
  final List<FacultyMember> faculty;
  final List<ClassModel> unassignedClasses;

  const _FacultyGrouping(this.faculty, this.unassignedClasses);

  factory _FacultyGrouping.from({
    required List<UserSearchResultModel> teachers,
    required List<ClassModel> classes,
    required Map<String, double> unitsBySubjectId,
  }) {
    final byTeacherId = <String, List<ClassModel>>{};
    final unassigned = <ClassModel>[];

    for (final c in classes) {
      if (c.userId != null && c.userId!.isNotEmpty) {
        byTeacherId.putIfAbsent(c.userId!, () => []).add(c);
      } else {
        unassigned.add(c);
      }
    }

    final members = teachers.map((teacher) {
      final assigned = byTeacherId[teacher.userId] ?? const <ClassModel>[];
      final units = assigned.fold<double>(
        0,
        (sum, c) => sum + (unitsBySubjectId[c.subjectId] ?? 0),
      );
      return FacultyMember(
        teacher: teacher,
        assignedClasses: assigned,
        totalUnits: units,
      );
    }).toList();

    members.sort((a, b) =>
        a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()));

    return _FacultyGrouping(members, unassigned);
  }
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

  /// Units come from the subject list. A failure there must not cost the page
  /// its faculty, so workload just shows 0 in that case.
  Future<Map<String, double>> _unitsBySubjectId() async {
    try {
      final subjects = await _classRepo.getSubjects();
      return {
        for (final s in subjects) s.subjectId: s.lecUnits + s.labUnits,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<_FacultyGrouping> _reload() async {
    final results = await Future.wait([
      _userSearchRepo.searchTeachingStaff(),
      _classRepo.getProgramClasses(),
      _unitsBySubjectId(),
    ]);

    return _FacultyGrouping.from(
      teachers: results[0] as List<UserSearchResultModel>,
      classes: results[1] as List<ClassModel>,
      unitsBySubjectId: results[2] as Map<String, double>,
    );
  }

  Future<void> _onLoad(
      LoadFacultyEvent event, Emitter<FacultyState> emit) async {
    emit(FacultyLoading());
    try {
      final grouped = await _reload();
      emit(FacultyLoaded(
        faculty: grouped.faculty,
        unassignedClasses: grouped.unassignedClasses,
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

      final grouped = await _reload();
      emit(FacultyLoaded(
        faculty: grouped.faculty,
        unassignedClasses: grouped.unassignedClasses,
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
