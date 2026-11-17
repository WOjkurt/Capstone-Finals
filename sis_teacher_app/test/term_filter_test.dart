import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_teacher_app/blocs/auth_bloc.dart';
import 'package:sis_teacher_app/blocs/classes_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/setup_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
import 'package:sis_teacher_app/views/my_classes_view.dart';
import 'package:sis_teacher_app/views/widgets/term_dropdown.dart';

const _active = AcademicTermModel(
  termId: 'term-2',
  schoolYear: '2026-2027',
  semester: 1,
  isActive: true,
);
const _past = AcademicTermModel(
  termId: 'term-1',
  schoolYear: '2025-2026',
  semester: 2,
  isActive: false,
);

class _FakeClassRepository implements ClassRepository {
  /// Every termId passed to getMyClasses, in order. null means "all terms".
  final List<String?> requestedTermIds = [];
  Map<String?, List<ClassModel>> classesByTerm = {};

  @override
  Future<List<ClassModel>> getMyClasses({
    required String teacherUserId,
    String? termId,
  }) async {
    requestedTermIds.add(termId);
    return classesByTerm[termId] ?? const [];
  }

  @override
  Future<List<AcademicTermModel>> getTerms() async => const [_active, _past];

  @override
  Future<AcademicTermModel?> getActiveTerm() async => _active;

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClassModel _class(String id, String code, String termId) => ClassModel(
      classId: id,
      subjectId: 'subj-$id',
      subjectCode: code,
      subjectTitle: '$code title',
      yearLevel: 1,
      userId: 't1',
      teacherName: 'Prof. Alan',
      termId: termId,
      className: 'BSIT 1A',
    );

AuthenticatedState _auth() => AuthenticatedState(
      email: 'teacher@dbtc-cebu.edu.ph',
      role: 3,
      roleName: 'Teacher',
      userId: 't1',
      fullName: 'Prof. Alan',
    );

void main() {
  final getIt = GetIt.instance;
  late _FakeClassRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = _FakeClassRepository();
    getIt.registerSingleton<ClassRepository>(repo);
  });

  tearDown(() async => getIt.reset());

  Future<ClassesBloc> pumpMyClasses(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bloc = ClassesBloc(repo);
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider<ClassesBloc>.value(
          value: bloc,
          child: MyClassesView(auth: _auth()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('My Classes opens on the active term, not every term', (tester) async {
    repo.classesByTerm = {
      'term-2': [_class('c2', 'IT 311', 'term-2')],
      'term-1': [_class('c1', 'IT 211', 'term-1')],
    };

    await pumpMyClasses(tester);

    expect(repo.requestedTermIds, ['term-2']);
    expect(find.text('IT 311'), findsOneWidget);
    expect(find.text('IT 211'), findsNothing);
  });

  testWidgets('picking a past term reloads that term', (tester) async {
    repo.classesByTerm = {
      'term-2': [_class('c2', 'IT 311', 'term-2')],
      'term-1': [_class('c1', 'IT 211', 'term-1')],
    };

    await pumpMyClasses(tester);

    await tester.tap(find.byType(TermDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025-2026 (2nd Sem)').last);
    await tester.pumpAndSettle();

    expect(repo.requestedTermIds, ['term-2', 'term-1']);
    expect(find.text('IT 211'), findsOneWidget);
    expect(find.text('IT 311'), findsNothing);
  });

  testWidgets('"All terms" clears the filter', (tester) async {
    repo.classesByTerm = {
      'term-2': [_class('c2', 'IT 311', 'term-2')],
      null: [
        _class('c2', 'IT 311', 'term-2'),
        _class('c1', 'IT 211', 'term-1'),
      ],
    };

    await pumpMyClasses(tester);

    await tester.tap(find.byType(TermDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All terms').last);
    await tester.pumpAndSettle();

    expect(repo.requestedTermIds, ['term-2', null]);
    expect(find.text('IT 311'), findsOneWidget);
    expect(find.text('IT 211'), findsOneWidget);
  });

  testWidgets('the page still loads when the term lookup fails', (tester) async {
    final failing = _FailingTermsRepository();
    await getIt.reset();
    getIt.registerSingleton<ClassRepository>(failing);

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bloc = ClassesBloc(failing);
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider<ClassesBloc>.value(
          value: bloc,
          child: MyClassesView(auth: _auth()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Falls back to every term rather than showing nothing.
    expect(failing.requestedTermIds, [null]);
    expect(find.byType(TermDropdown), findsNothing);
    expect(find.text('IT 311'), findsOneWidget);
  });
}

class _FailingTermsRepository extends _FakeClassRepository {
  _FailingTermsRepository() {
    classesByTerm = {
      null: [_class('c2', 'IT 311', 'term-2')],
    };
  }

  @override
  Future<List<AcademicTermModel>> getTerms() async =>
      throw Exception('terms unavailable');
}
