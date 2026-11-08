import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';

// ── Fake repository ──────────────────────────────────────────────────────────

class _FakeSetupRepo implements AcademicSetupRepository {
  /// Records the last call arguments for addPrerequisite.
  String? lastAddedSubjectId;
  String? lastAddedPrereqId;
  int? lastAddedRequisiteType;

  /// Controls what getPrerequisites returns.
  List<PrerequisiteModel> prereqs = [];

  @override
  Future<List<AcademicProgramModel>> getPrograms() async => [];

  @override
  Future<AcademicProgramModel> createProgram(
          {required String code, required String name}) async =>
      AcademicProgramModel(programId: 1, programCode: code, programName: name);

  @override
  Future<AcademicProgramModel> updateProgram(int id,
          {required String code, required String name}) async =>
      AcademicProgramModel(programId: id, programCode: code, programName: name);

  @override
  Future<void> deleteProgram(int id) async {}

  @override
  Future<List<AcademicTermModel>> getTerms() async => [];

  @override
  Future<AcademicTermModel> createTerm(
          {required String schoolYear, required int semester}) async =>
      AcademicTermModel(termId: 'new', schoolYear: schoolYear, semester: semester);

  @override
  Future<AcademicTermModel> updateTerm(String id,
          {required String schoolYear, required int semester}) async =>
      AcademicTermModel(termId: id, schoolYear: schoolYear, semester: semester);

  @override
  Future<void> deleteTerm(String id) async {}

  @override
  Future<AcademicTermModel> setEnrollmentPeriod(String id, {DateTime? opensOn, DateTime? closesOn}) async =>
      throw UnimplementedError();

  @override
  Future<AcademicTermModel> activateTerm(String id) async =>
      AcademicTermModel(termId: id, schoolYear: '2025-2026', semester: 1, isActive: true);

  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async => [];

  @override
  Future<SubjectModel> createSubject(Map<String, dynamic> dto) async =>
      SubjectModel.fromJson({...dto, 'subjectID': 'subj-new'});

  @override
  Future<SubjectModel> updateSubject(String id, Map<String, dynamic> dto) async =>
      SubjectModel.fromJson({...dto, 'subjectID': id});

  @override
  Future<void> deleteSubject(String id) async {}

  @override
  Future<List<PrerequisiteModel>> getPrerequisites(String subjectId) async => prereqs;

  @override
  Future<void> addPrerequisite(String subjectId, String prerequisiteSubjectId,
      {int requisiteType = 0}) async {
    lastAddedSubjectId = subjectId;
    lastAddedPrereqId = prerequisiteSubjectId;
    lastAddedRequisiteType = requisiteType;
    // Simulate the server adding the row to prereqs
    prereqs = [
      PrerequisiteModel(
        prerequisiteId: 'new-prereq',
        subjectId: subjectId,
        prerequisiteSubjectId: prerequisiteSubjectId,
        prerequisiteSubjectCode: 'SBJ',
        prerequisiteSubjectTitle: 'Subject',
        requisiteType: requisiteType,
      ),
    ];
  }

  @override
  Future<void> removePrerequisite(String prerequisiteId) async {
    prereqs = prereqs.where((p) => p.prerequisiteId != prerequisiteId).toList();
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── PrerequisiteModel.fromJson ───────────────────────────────────────────────

  group('PrerequisiteModel.fromJson', () {
    test('defaults requisiteType to 0 when field is absent', () {
      final json = {
        'prerequisiteID': 'p1',
        'subjectID': 's1',
        'prerequisiteSubjectID': 'p-sub',
        'prerequisiteSubjectCode': 'CS100',
        'prerequisiteSubjectTitle': 'Intro',
        // requisiteType not included
      };
      final model = PrerequisiteModel.fromJson(json);
      expect(model.requisiteType, equals(0));
      expect(model.isCorequisite, isFalse);
    });

    test('parses requisiteType 0 as prerequisite', () {
      final json = {
        'prerequisiteID': 'p1',
        'subjectID': 's1',
        'prerequisiteSubjectID': 'p-sub',
        'requisiteType': 0,
      };
      final model = PrerequisiteModel.fromJson(json);
      expect(model.requisiteType, equals(0));
      expect(model.isCorequisite, isFalse);
    });

    test('parses requisiteType 1 as corequisite', () {
      final json = {
        'prerequisiteID': 'p2',
        'subjectID': 's2',
        'prerequisiteSubjectID': 'p-sub2',
        'requisiteType': 1,
      };
      final model = PrerequisiteModel.fromJson(json);
      expect(model.requisiteType, equals(1));
      expect(model.isCorequisite, isTrue);
    });

    test('isCorequisite is false for type 0', () {
      const m = PrerequisiteModel(
        prerequisiteId: 'x',
        subjectId: 'a',
        prerequisiteSubjectId: 'b',
        requisiteType: 0,
      );
      expect(m.isCorequisite, isFalse);
    });

    test('isCorequisite is true for type 1', () {
      const m = PrerequisiteModel(
        prerequisiteId: 'x',
        subjectId: 'a',
        prerequisiteSubjectId: 'b',
        requisiteType: 1,
      );
      expect(m.isCorequisite, isTrue);
    });
  });

  // ── AddPrerequisiteEvent carries requisiteType ───────────────────────────────

  group('AddPrerequisiteEvent', () {
    test('defaults requisiteType to 0 when not specified', () {
      final evt = AddPrerequisiteEvent('sub-1', 'prereq-1');
      expect(evt.requisiteType, equals(0));
    });

    test('carries requisiteType 1 when specified', () {
      final evt = AddPrerequisiteEvent('sub-1', 'prereq-1', requisiteType: 1);
      expect(evt.requisiteType, equals(1));
    });
  });

  // ── SetupBloc: AddPrerequisiteEvent sends requisiteType to the repository ────

  group('SetupBloc AddPrerequisiteEvent', () {
    late _FakeSetupRepo fakeRepo;
    late SetupBloc bloc;

    setUp(() {
      fakeRepo = _FakeSetupRepo();
      bloc = SetupBloc(fakeRepo);
    });

    tearDown(() => bloc.close());

    test('sends requisiteType 0 (prerequisite) to repository', () async {
      // Pre-select a subject
      final subject = SubjectModel.fromJson({
        'subjectID': 'subj-a',
        'subjectCode': 'A',
        'subjectTitle': 'A',
        'lecUnits': 3.0,
        'labUnits': 0.0,
        'lecHours': 3.0,
        'labHours': 0.0,
        'programID': 1,
        'yearLevel': 1,
        'defaultSemester': 1,
      });
      bloc.add(SelectSubjectForPrereqs(subject));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(AddPrerequisiteEvent('subj-a', 'prereq-b', requisiteType: 0));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeRepo.lastAddedRequisiteType, equals(0));
      expect(fakeRepo.lastAddedSubjectId, equals('subj-a'));
      expect(fakeRepo.lastAddedPrereqId, equals('prereq-b'));
    });

    test('sends requisiteType 1 (corequisite) to repository', () async {
      final subject = SubjectModel.fromJson({
        'subjectID': 'subj-a',
        'subjectCode': 'A',
        'subjectTitle': 'A',
        'lecUnits': 3.0,
        'labUnits': 0.0,
        'lecHours': 3.0,
        'labHours': 0.0,
        'programID': 1,
        'yearLevel': 1,
        'defaultSemester': 1,
      });
      bloc.add(SelectSubjectForPrereqs(subject));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(AddPrerequisiteEvent('subj-a', 'cosubjB', requisiteType: 1));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeRepo.lastAddedRequisiteType, equals(1));
    });

    test('on success, state.prerequisites reflects the new row with correct type', () async {
      fakeRepo.prereqs = []; // start empty
      final subject = SubjectModel.fromJson({
        'subjectID': 'subj-a',
        'subjectCode': 'A',
        'subjectTitle': 'A',
        'lecUnits': 3.0,
        'labUnits': 0.0,
        'lecHours': 3.0,
        'labHours': 0.0,
        'programID': 1,
        'yearLevel': 1,
        'defaultSemester': 1,
      });
      bloc.add(SelectSubjectForPrereqs(subject));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(AddPrerequisiteEvent('subj-a', 'prereq-b', requisiteType: 1));
      await Future.delayed(const Duration(milliseconds: 100));

      final state = bloc.state;
      expect(state.prerequisites.length, equals(1));
      expect(state.prerequisites.first.requisiteType, equals(1));
      expect(state.prerequisites.first.isCorequisite, isTrue);
    });
  });
}
