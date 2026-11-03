import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/views/setup_view.dart';

/// Records events instead of calling the API.
class RecordingSetupBloc extends Bloc<SetupEvent, SetupState> implements SetupBloc {
  final List<SetupEvent> events = [];
  RecordingSetupBloc(super.initialState) {
    on<SetupEvent>((event, emit) => events.add(event));
  }
}

const _program = AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT');

SubjectModel _subject(String id, String code, {bool isMinor = false}) => SubjectModel(
      subjectId: id,
      subjectCode: code,
      subjectTitle: '$code title',
      lecUnits: 3,
      labUnits: 0,
      lecHours: 3,
      labHours: 0,
      programId: 1,
      programCode: 'BSIT',
      yearLevel: 1,
      defaultSemester: 1,
      isMinor: isMinor,
    );

void main() {
  test('SubjectModel parses isMinor (defaults to false)', () {
    final base = {'subjectID': 's', 'subjectCode': 'X', 'subjectTitle': 'T', 'programID': 1};
    expect(SubjectModel.fromJson({...base, 'isMinor': true}).isMinor, isTrue);
    expect(SubjectModel.fromJson(base).isMinor, isFalse);
  });

  Future<RecordingSetupBloc> pumpSubjects(WidgetTester tester, List<SubjectModel> subjects) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = RecordingSetupBloc(SetupState(activeTab: 2, programs: const [_program], subjects: subjects));
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<SetupBloc>.value(value: bloc, child: const SetupView()),
    ));
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('subject table shows a Minor badge only on minor subjects', (tester) async {
    await pumpSubjects(tester, [
      _subject('s1', 'THEO 101A', isMinor: true),
      _subject('s2', 'IT 101A'),
    ]);

    expect(find.text('Minor'), findsOneWidget);
  });

  testWidgets('editing a minor subject starts checked; unticking sends isMinor false', (tester) async {
    final bloc = await pumpSubjects(tester, [_subject('s1', 'THEO 101A', isMinor: true)]);

    await tester.tap(find.byTooltip('Edit Subject'));
    await tester.pumpAndSettle();

    final checkbox = find.byKey(const ValueKey('subject_is_minor_checkbox'));
    expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);

    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
    await tester.pumpAndSettle();

    final update = bloc.events.whereType<UpdateSubjectEvent>().single;
    expect(update.id, 's1');
    expect(update.dto['isMinor'], isFalse);
  });

  testWidgets('a new subject is major unless the box is ticked', (tester) async {
    final bloc = await pumpSubjects(tester, []);

    await tester.tap(find.text('Add Subject'));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(const ValueKey('subject_is_minor_checkbox'));
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Subject Code *'), 'GEC 101A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject Title *'), 'Math in the Modern World');
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Subject'));
    await tester.pumpAndSettle();

    final create = bloc.events.whereType<CreateSubjectEvent>().single;
    expect(create.dto['subjectCode'], 'GEC 101A');
    expect(create.dto['isMinor'], isTrue);
  });
}
