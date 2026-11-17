import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/blocs/pending_loads_bloc.dart';
import 'package:sis_college_head_app/models/class_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/repositories/setup_repository.dart';
import 'test_helpers.dart';

const _terms = [
  {'termID': 't2', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
  {'termID': 't1', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
];

Map<String, Object?> _pendingRow(
  String name, {
  int count = 2,
  double units = 6,
  bool overloaded = false,
}) =>
    {
      'userId': 'u-$name',
      'fullName': name,
      'programCode': 'BSIT',
      'yearLevel': 2,
      'pendingCount': count,
      'pendingUnits': units,
      'termUnits': overloaded ? 27 : 21,
      'maxUnits': 21,
      'isOverloaded': overloaded,
      if (overloaded) 'overloadReason': 'Graduating this year',
      if (overloaded) 'overloadApprovedBy': 'Carla Head',
    };

/// Records every pending-summary termId the bloc asked for.
class _Api {
  final List<String> requestedTermIds = [];
  List<Map<String, Object?>> rows = [];
  bool failPending = false;

  MockClient get client => MockClient((req) async {
        final path = req.url.path.toLowerCase();
        if (path.endsWith('/api/academicterms')) {
          return http.Response(jsonEncode(_terms), 200);
        }
        if (path.endsWith('/api/studyloads/pending-summary')) {
          requestedTermIds.add(req.url.queryParameters['termId'] ?? '');
          if (failPending) {
            return http.Response(
                jsonEncode({'message': 'Server exploded'}), 500);
          }
          return http.Response(jsonEncode(rows), 200);
        }
        return http.Response('[]', 200);
      });
}

void main() {
  group('PendingStudyLoadSummaryModel', () {
    test('parses the overload fields', () {
      final m = PendingStudyLoadSummaryModel.fromJson(
          _pendingRow('Dela Cruz, Ana', overloaded: true));

      expect(m.isOverloaded, isTrue);
      expect(m.termUnits, 27);
      expect(m.maxUnits, 21);
      expect(m.termUnitsLabel, '27/21');
      expect(m.overloadReason, 'Graduating this year');
      expect(m.overloadApprovedBy, 'Carla Head');
    });

    test('defaults the overload fields when the API omits them', () {
      final m = PendingStudyLoadSummaryModel.fromJson(const {
        'userId': 'u1',
        'fullName': 'Reyes, Mark',
        'pendingCount': 1,
        'pendingUnits': 3,
      });

      expect(m.isOverloaded, isFalse);
      expect(m.overloadReason, isNull);
    });

    test('drops a trailing .0 from unit labels', () {
      expect(
        PendingStudyLoadSummaryModel.fromJson(
                _pendingRow('A', units: 6)).pendingUnitsLabel,
        '6',
      );
      expect(
        PendingStudyLoadSummaryModel.fromJson(
                _pendingRow('A', units: 4.5)).pendingUnitsLabel,
        '4.5',
      );
    });
  });

  group('PendingLoadsBloc', () {
    late _Api api;
    late PendingLoadsBloc bloc;

    setUp(() {
      api = _Api();
      bloc = PendingLoadsBloc(
        ClassRepository(MockAuthService(), api.client),
        AcademicSetupRepository(MockAuthService(), api.client),
      );
    });

    tearDown(() => bloc.close());

    test('starts on the active term and loads it', () async {
      api.rows = [_pendingRow('Dela Cruz, Ana'), _pendingRow('Reyes, Mark')];

      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.selectedTermId, 't2');
      expect(api.requestedTermIds, ['t2']);
      expect(bloc.state.pending, hasLength(2));
      expect(bloc.state.isLoading, isFalse);
    });

    test('totals students, subjects and overloads', () async {
      api.rows = [
        _pendingRow('Dela Cruz, Ana', count: 2),
        _pendingRow('Reyes, Mark', count: 3, overloaded: true),
      ];

      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.studentCount, 2);
      expect(bloc.state.subjectCount, 5);
      expect(bloc.state.overloadedCount, 1);
    });

    test('switching term reloads for that term', () async {
      api.rows = [_pendingRow('Dela Cruz, Ana')];

      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      bloc.add(PendingLoadsTermSelected('t1'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(api.requestedTermIds, ['t2', 't1']);
      expect(bloc.state.selectedTermId, 't1');
    });

    test('picking the term already shown does not refetch', () async {
      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      bloc.add(PendingLoadsTermSelected('t2'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(api.requestedTermIds, ['t2']);
    });

    test('a failed load reports the error and clears the list', () async {
      api.rows = [_pendingRow('Dela Cruz, Ana')];
      api.failPending = true;

      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.pending, isEmpty);
      expect(bloc.state.isLoading, isFalse);
    });

    test('an empty term is not an error', () async {
      api.rows = [];

      bloc.add(PendingLoadsStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.pending, isEmpty);
      expect(bloc.state.errorMessage, isNull);
    });
  });
}
