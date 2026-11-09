import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/error_handler.dart';
import 'package:sis_registrar_app/views/widgets/edit_lrn_dialog.dart';
import 'package:sis_registrar_app/views/widgets/status_badge.dart';

class MockUserSearchRepository implements UserSearchRepository {
  String? lastQuery;
  int? lastRole;
  bool? lastMissingLrn;
  List<UserSearchResultModel> resultsToReturn = [];
  String? updatedUserId;
  String? updatedLrn;

  @override
  Future<List<UserSearchResultModel>> search({
    String? query,
    int? role,
    bool? missingLrn,
    int? programId,
  }) async {
    lastQuery = query;
    lastRole = role;
    lastMissingLrn = missingLrn;
    return resultsToReturn;
  }

  @override
  @override
  Future<String?> updateStudentId(String userId, String? studentId) async => studentId;

  Future<void> updateStudentLrn(String userId, String? lrn) async {
    updatedUserId = userId;
    updatedLrn = lrn;
  }

  @override
  Future<void> updateStudentYearLevel(String userId, int yearLevel) async {
    // stub – not exercised in LRN tests
  }

  @override
  Future<YearLevelSuggestionModel> getYearLevelSuggestion(String userId) =>
      throw UnimplementedError();
}

class MockGradeClearanceRepository implements GradeClearanceRepository {
  @override
  Future<List<GradeClearanceModel>> getClearancesForUser(String userId) async {
    return [];
  }

  @override
  Future<GradeClearanceModel> toggleClearance(String userId, String termId, bool isCleared) async {
    return GradeClearanceModel(
      clearanceId: 'c1',
      userId: userId,
      termId: termId,
      isCleared: isCleared,
    );
  }

  @override
  Future<GradeClearanceModel> createClearance({required String userId, required String termId, bool isCleared = false}) async {
    return GradeClearanceModel(
      clearanceId: 'c2',
      userId: userId,
      termId: termId,
      isCleared: isCleared,
    );
  }
}

void main() {
  group('LRN Models Serialization & Parsing', () {
    test('ClassRosterItemModel parses lrn and hasLrn from json', () {
      final jsonWithLrn = {
        'classRosterID': 'cr-1',
        'studentUserID': 'stu-1',
        'displayName': 'Juan Dela Cruz',
        'loadStatus': '1',
        'lrn': '123456789012',
        'hasLrn': true,
      };
      final item1 = ClassRosterItemModel.fromJson(jsonWithLrn);
      expect(item1.lrn, '123456789012');
      expect(item1.hasLrn, isTrue);

      final jsonWithoutLrn = {
        'classRosterID': 'cr-2',
        'studentUserID': 'stu-2',
        'displayName': 'Maria Clara',
        'loadStatus': '1',
        'hasLrn': false,
      };
      final item2 = ClassRosterItemModel.fromJson(jsonWithoutLrn);
      expect(item2.lrn, isNull);
      expect(item2.hasLrn, isFalse);
    });

    test('UserSearchResultModel parses and copies lrn and hasLrn correctly', () {
      final json = {
        'userID': 'user-10',
        'firstname': 'Pedro',
        'lastname': 'Penduko',
        'email': 'pedro@school.edu',
        'role': 5,
        'lrn': '987654321098',
        'hasLrn': true,
      };
      final model = UserSearchResultModel.fromJson(json);
      expect(model.lrn, '987654321098');
      expect(model.hasLrn, isTrue);

      final updated = model.copyWith(clearLrn: true, hasLrn: false);
      expect(updated.lrn, isNull);
      expect(updated.hasLrn, isFalse);
      expect(updated.fullName, 'Pedro Penduko');
    });
  });

  group('StatusBadge.noLrn widget', () {
    testWidgets('renders amber badge with "No LRN" label and responds to tap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusBadge.noLrn(
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('No LRN'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.text('No LRN'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('EditLrnDialog widget', () {
    testWidgets('validates 12 digits and rejects letters or wrong lengths',
        (tester) async {
      String? savedLrn;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditLrnDialog(
              title: 'Edit Student Profile LRN',
              targetName: 'Test Student',
              initialLrn: '123',
              onSave: (cleanLrn) async {
                savedLrn = cleanLrn;
              },
            ),
          ),
        ),
      );

      expect(find.text('Edit Student Profile LRN'), findsOneWidget);
      expect(find.text('Test Student'), findsOneWidget);

      // Tap Save with 3 digits -> validation error
      await tester.tap(find.text('Save LRN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('exactly 12 digits'), findsOneWidget);
      expect(savedLrn, isNull);

      // Enter 12 non-digit characters
      final inputFinder = find.byType(TextFormField);
      await tester.enterText(inputFinder, 'abcdefghijkl');
      await tester.tap(find.text('Save LRN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('digits only'), findsOneWidget);
      expect(savedLrn, isNull);

      // Enter valid 12-digit number with spaces/dashes
      await tester.enterText(inputFinder, '1234-5678 9012');
      await tester.tap(find.text('Save LRN'));
      await tester.pumpAndSettle();

      expect(savedLrn, '123456789012');
    });

    testWidgets('empty input allows clearing LRN', (tester) async {
      bool onSaveCalled = false;
      String? savedLrn = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditLrnDialog(
              title: 'Edit Application Form LRN',
              targetName: 'Applicant One',
              initialLrn: '123456789012',
              onSave: (cleanLrn) async {
                onSaveCalled = true;
                savedLrn = cleanLrn;
              },
            ),
          ),
        ),
      );

      final inputFinder = find.byType(TextFormField);
      await tester.enterText(inputFinder, '');
      await tester.tap(find.text('Save LRN'));
      await tester.pumpAndSettle();

      expect(onSaveCalled, isTrue);
      expect(savedLrn, isNull);
    });

    testWidgets('displays server error clearly when onSave throws ApiException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditLrnDialog(
              title: 'Edit Student Profile LRN',
              targetName: 'Duplicate Student',
              initialLrn: '',
              onSave: (cleanLrn) async {
                throw ApiException(
                  statusCode: 400,
                  message: 'LRN is already assigned to another student.',
                );
              },
            ),
          ),
        ),
      );

      final inputFinder = find.byType(TextFormField);
      await tester.enterText(inputFinder, '123456789012');
      await tester.tap(find.text('Save LRN'));
      await tester.pumpAndSettle();

      expect(
        find.text('LRN is already assigned to another student.'),
        findsOneWidget,
      );
    });
  });

  group('ClearanceBloc missingLrn filter and update events', () {
    late MockUserSearchRepository userRepo;
    late MockGradeClearanceRepository clearanceRepo;
    late ClearanceBloc bloc;

    setUp(() {
      userRepo = MockUserSearchRepository();
      clearanceRepo = MockGradeClearanceRepository();
      bloc = ClearanceBloc(userRepo, clearanceRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('ToggleMissingLrnFilterEvent passes missingLrn = true to repository',
        () async {
      final student1 = UserSearchResultModel(
        userId: 's-1',
        firstname: 'Ana',
        lastname: 'Santos',
        email: 'ana@school.edu',
        role: 5,
        lrn: null,
        hasLrn: false,
      );
      userRepo.resultsToReturn = [student1];

      bloc.add(ToggleMissingLrnFilterEvent(true));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as ClearanceStateData;
      expect(state.missingLrnOnly, isTrue);
      expect(state.searchResults.length, 1);
      expect(userRepo.lastMissingLrn, isTrue);
    });

    test('StudentLrnUpdatedEvent updates selected student and search results',
        () async {
      final student1 = UserSearchResultModel(
        userId: 's-1',
        firstname: 'Ana',
        lastname: 'Santos',
        email: 'ana@school.edu',
        role: 5,
        lrn: null,
        hasLrn: false,
      );
      userRepo.resultsToReturn = [student1];

      bloc.add(SelectStudentEvent(student1));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(StudentLrnUpdatedEvent('s-1', '123456789012'));
      await Future.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as ClearanceStateData;
      expect(state.selectedStudent?.lrn, '123456789012');
      expect(state.selectedStudent?.hasLrn, isTrue);
    });
  });
}
