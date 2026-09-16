import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/repositories/grading_repository.dart';
import 'package:sis_teacher_app/services/auth_service.dart';
import 'package:sis_teacher_app/views/widgets/assign_teacher_dialog.dart';

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserSearchRepository extends UserSearchRepository {
  List<UserSearchResultModel> mockTeachers = [];

  _FakeUserSearchRepository() : super(_FakeAuthService());

  @override
  Future<List<UserSearchResultModel>> search({String? query, int? role}) async {
    if (query != null && query.isNotEmpty) {
      return mockTeachers
          .where((t) =>
              t.fullName.toLowerCase().contains(query.toLowerCase()) ||
              t.email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    return mockTeachers;
  }
}

void main() {
  final getIt = GetIt.instance;
  late _FakeUserSearchRepository fakeSearchRepo;

  final teacher1 = UserSearchResultModel(
    userId: 'teacher-1',
    firstname: 'John',
    lastname: 'Doe',
    email: 'john.doe@dbtc-cebu.edu.ph',
    role: 3,
    roleName: 'Teacher',
    programId: 1,
    programCode: 'BSIT',
  );

  final teacher2 = UserSearchResultModel(
    userId: 'teacher-2',
    firstname: 'Jane',
    lastname: 'Smith',
    email: 'jane.smith@dbtc-cebu.edu.ph',
    role: 3,
    roleName: 'Teacher',
    programId: 1,
    programCode: 'BSIT',
  );

  setUp(() async {
    await getIt.reset();
    fakeSearchRepo = _FakeUserSearchRepository();
    fakeSearchRepo.mockTeachers = [teacher1, teacher2];
    getIt.registerLazySingleton<UserSearchRepository>(() => fakeSearchRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildTestHarness({
    required ClassModel classItem,
    required void Function(String?) onAssign,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AssignTeacherDialog(
                    classItem: classItem,
                    onAssign: onAssign,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'confirmation shown before remove, cancel aborts the removal, confirm proceeds',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const assignedClass = ClassModel(
      classId: 'c-1',
      subjectId: 's-1',
      subjectCode: 'IT 101',
      subjectTitle: 'Intro to Computing',
      userId: 'teacher-1',
      teacherName: 'John Doe',
      termId: 't-1',
      className: 'BSIT-1A',
    );

    String? assignedTeacherId = 'initial';
    bool callbackCalled = false;

    await tester.pumpWidget(
      buildTestHarness(
        classItem: assignedClass,
        onAssign: (id) {
          callbackCalled = true;
          assignedTeacherId = id;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify "Remove Assignment" button is found
    final removeBtn = find.byKey(const ValueKey('remove_assignment_button'));
    expect(removeBtn, findsOneWidget);

    // Tap "Remove Assignment" -> should show confirmation dialog
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    // Verify confirmation dialog is visible with expected content
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        'Remove John Doe from IT 101 — BSIT-1A? This class will become unassigned.',
      ),
      findsOneWidget,
    );

    // Tap "Cancel" in confirmation dialog -> aborts removal
    final cancelRemoveBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Cancel'),
    );
    await tester.tap(cancelRemoveBtn);
    await tester.pumpAndSettle();

    expect(callbackCalled, isFalse);
    expect(assignedTeacherId, 'initial');
    // AssignTeacherDialog should still be open
    expect(find.byType(AssignTeacherDialog), findsOneWidget);

    // Tap "Remove Assignment" again
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    // Confirm removal by tapping red "Remove" button
    final confirmRemoveBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Remove'),
    );
    expect(confirmRemoveBtn, findsOneWidget);
    await tester.tap(confirmRemoveBtn);
    await tester.pumpAndSettle();

    expect(callbackCalled, isTrue);
    expect(assignedTeacherId, isNull);
  });

  testWidgets(
      'confirmation shown before reassign over an existing teacher, cancel aborts, confirm proceeds',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const assignedClass = ClassModel(
      classId: 'c-1',
      subjectId: 's-1',
      subjectCode: 'IT 101',
      subjectTitle: 'Intro to Computing',
      userId: 'teacher-1',
      teacherName: 'John Doe',
      termId: 't-1',
      className: 'BSIT-1A',
    );

    String? assignedTeacherId;
    bool callbackCalled = false;

    await tester.pumpWidget(
      buildTestHarness(
        classItem: assignedClass,
        onAssign: (id) {
          callbackCalled = true;
          assignedTeacherId = id;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Select Jane Smith
    expect(find.text('Jane Smith'), findsOneWidget);
    await tester.tap(find.text('Jane Smith'));
    await tester.pumpAndSettle();

    // Tap "Reassign" button in AssignTeacherDialog
    expect(find.text('Reassign'), findsOneWidget);
    await tester.tap(find.text('Reassign'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog is visible with expected content
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        'Reassign IT 101 — BSIT-1A from John Doe to Jane Smith?',
      ),
      findsOneWidget,
    );

    // Tap "Cancel" in confirmation dialog -> aborts reassignment
    final cancelReassignBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Cancel'),
    );
    await tester.tap(cancelReassignBtn);
    await tester.pumpAndSettle();

    expect(callbackCalled, isFalse);
    expect(find.byType(AssignTeacherDialog), findsOneWidget);

    // Tap "Reassign" button in AssignTeacherDialog again
    await tester.tap(find.text('Reassign'));
    await tester.pumpAndSettle();

    // Confirm reassignment by tapping "Reassign" in the AlertDialog
    final confirmReassignBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Reassign'),
    );
    expect(confirmReassignBtn, findsOneWidget);
    await tester.tap(confirmReassignBtn);
    await tester.pumpAndSettle();

    expect(callbackCalled, isTrue);
    expect(assignedTeacherId, 'teacher-2');
  });

  testWidgets(
      'plain assign (no prior teacher) still fires immediately without a confirmation step',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const unassignedClass = ClassModel(
      classId: 'c-3',
      subjectId: 's-1',
      subjectCode: 'IT 101',
      subjectTitle: 'Intro to Computing',
      userId: null,
      teacherName: null,
      termId: 't-1',
      className: 'BSIT-1C',
    );

    String? assignedTeacherId;
    bool callbackCalled = false;

    await tester.pumpWidget(
      buildTestHarness(
        classItem: unassignedClass,
        onAssign: (id) {
          callbackCalled = true;
          assignedTeacherId = id;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap on the teacher result
    expect(find.text('John Doe'), findsOneWidget);
    await tester.tap(find.text('John Doe'));
    await tester.pumpAndSettle();

    // Tap "Assign" button
    expect(find.text('Assign'), findsOneWidget);
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    // Confirmation dialog should NOT appear; should immediately fire callback
    expect(find.byType(AlertDialog), findsNothing);
    expect(callbackCalled, isTrue);
    expect(assignedTeacherId, 'teacher-1');
  });

  testWidgets('hides "Remove Assignment" button when class is unassigned',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const unassignedClass = ClassModel(
      classId: 'c-2',
      subjectId: 's-1',
      subjectCode: 'IT 101',
      subjectTitle: 'Intro to Computing',
      userId: null,
      teacherName: null,
      termId: 't-1',
      className: 'BSIT-1B',
    );

    await tester.pumpWidget(
      buildTestHarness(
        classItem: unassignedClass,
        onAssign: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify "Remove Assignment" button is NOT found
    expect(find.byKey(const ValueKey('remove_assignment_button')), findsNothing);
    expect(find.text('Remove Assignment'), findsNothing);
  });
}
