import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/blocs/irregular_bloc.dart';
import 'package:sis_college_head_app/models/grading_models.dart';
import 'package:sis_college_head_app/repositories/student_repository.dart';
import 'test_helpers.dart';

Map<String, Object?> _row(
  String name, {
  String program = 'BSIT',
  double backUnits = 3,
  bool ready = false,
  String? since,
}) =>
    {
      'userId': 'u-$name',
      'studentName': name,
      'programCode': program,
      'yearLevel': 2,
      'backMajorUnitsPassed': backUnits,
      'readyToBeRegular': ready,
      'irregularSince': ?since,
    };

IrregularBloc _blocFor(List<Map<String, Object?>> rows, {bool fail = false}) {
  final client = MockClient((req) async {
    if (fail) {
      return http.Response(jsonEncode({'message': 'Server exploded'}), 500);
    }
    return http.Response(jsonEncode(rows), 200);
  });
  return IrregularBloc(StudentRepository(MockAuthService(), client));
}

void main() {
  group('IrregularStudentModel', () {
    test('parses the standing fields', () {
      final m = IrregularStudentModel.fromJson(
          _row('Cruz, Ana', backUnits: 6, ready: true, since: '2025-08-01T00:00:00Z'));

      expect(m.studentName, 'Cruz, Ana');
      expect(m.backMajorUnitsPassed, 6);
      expect(m.readyToBeRegular, isTrue);
      expect(m.irregularSince, isNotNull);
      expect(m.progressLabel, '6/6 units');
    });

    test('defaults missing fields rather than throwing', () {
      final m = IrregularStudentModel.fromJson(const {'userId': 'u1'});

      expect(m.studentName, 'Unknown Student');
      expect(m.backMajorUnitsPassed, 0);
      expect(m.readyToBeRegular, isFalse);
      expect(m.irregularSince, isNull);
    });

    test('drops a trailing .0 from the progress label', () {
      expect(IrregularStudentModel.fromJson(_row('A', backUnits: 4.5)).progressLabel,
          '4.5/6 units');
      expect(IrregularStudentModel.fromJson(_row('A', backUnits: 3)).progressLabel,
          '3/6 units');
    });
  });

  group('IrregularBloc', () {
    test('loads and sorts by name', () async {
      final bloc = _blocFor([_row('Santos, Ben'), _row('Cruz, Ana')]);
      addTearDown(bloc.close);

      bloc.add(IrregularStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.students.map((s) => s.studentName),
          ['Cruz, Ana', 'Santos, Ben']);
      expect(bloc.state.isLoading, isFalse);
    });

    test('splits those ready to be regular from those still short', () async {
      final bloc = _blocFor([
        _row('Cruz, Ana', backUnits: 6, ready: true),
        _row('Santos, Ben', backUnits: 3),
        _row('Lim, Grace', backUnits: 0),
      ]);
      addTearDown(bloc.close);

      bloc.add(IrregularStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.ready.map((s) => s.studentName), ['Cruz, Ana']);
      expect(bloc.state.stillShort.map((s) => s.studentName),
          ['Lim, Grace', 'Santos, Ben']);
    });

    test('offers the programs present and filters by one', () async {
      final bloc = _blocFor([
        _row('Cruz, Ana', program: 'BSIT'),
        _row('Santos, Ben', program: 'BSME'),
        _row('Lim, Grace', program: 'BSIT'),
      ]);
      addTearDown(bloc.close);

      bloc.add(IrregularStarted());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.programCodes, ['BSIT', 'BSME']);
      expect(bloc.state.visible, hasLength(3));

      bloc.add(IrregularProgramFiltered('BSME'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.visible.map((s) => s.studentName), ['Santos, Ben']);

      // Back to every program.
      bloc.add(IrregularProgramFiltered(null));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.visible, hasLength(3));
    });

    test('a failed load reports the error and shows no students', () async {
      final bloc = _blocFor([], fail: true);
      addTearDown(bloc.close);

      bloc.add(IrregularStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.students, isEmpty);
      expect(bloc.state.isLoading, isFalse);
    });

    test('no irregular students is not an error', () async {
      final bloc = _blocFor([]);
      addTearDown(bloc.close);

      bloc.add(IrregularStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.students, isEmpty);
      expect(bloc.state.errorMessage, isNull);
    });
  });
}
