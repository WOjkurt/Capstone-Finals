import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/views/setup_view.dart';

class RecordingSetupBloc extends Bloc<SetupEvent, SetupState> implements SetupBloc {
  final List<SetupEvent> events = [];
  RecordingSetupBloc(super.initialState) {
    on<SetupEvent>((event, emit) => events.add(event));
  }
}

void main() {
  test('AcademicProgramModel reads the major and builds the full name', () {
    final mt = AcademicProgramModel.fromJson({
      'programID': 2,
      'programCode': 'BTVTED-MT',
      'programName': 'Bachelor of Technical-Vocational Teacher Education',
      'major': 'Mechanical Technology',
    });
    expect(mt.fullName, 'Bachelor of Technical-Vocational Teacher Education, Major in Mechanical Technology');
    expect(const AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT').fullName, 'BS IT');
  });

  Future<RecordingSetupBloc> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = RecordingSetupBloc(SetupState(activeTab: 0, programs: const [
      AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT'),
      AcademicProgramModel(programId: 2, programCode: 'BTVTED-FT', programName: 'BTVTEd', major: 'Furniture Technology'),
    ]));
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(home: BlocProvider<SetupBloc>.value(value: bloc, child: const SetupView())));
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('the programs table has a Major column', (tester) async {
    await pump(tester);
    expect(find.text('Major'), findsOneWidget);
    expect(find.text('Furniture Technology'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // BSIT has none
  });

  testWidgets('adding a program sends the major; editing can clear it', (tester) async {
    final bloc = await pump(tester);
    await tester.tap(find.text('Add Academic Program'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Program Code *'), 'BTVTED-MT');
    await tester.enterText(find.widgetWithText(TextFormField, 'Program Name *'), 'BTVTEd');
    await tester.enterText(find.byKey(const ValueKey('program_major_field')), ' Mechanical Technology ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final created = bloc.events.whereType<CreateProgramEvent>().single;
    expect(created.code, 'BTVTED-MT');
    expect(created.major, 'Mechanical Technology');

    await tester.tap(find.byTooltip('Edit Program').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Furniture Technology'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('program_major_field')), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    final updated = bloc.events.whereType<UpdateProgramEvent>().single;
    expect(updated.id, 2);
    expect(updated.major, isNull);
  });
}
