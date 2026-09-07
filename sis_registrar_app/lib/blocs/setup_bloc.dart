import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';

// Events
abstract class SetupEvent {}

class LoadSetupData extends SetupEvent {
  final int activeTab;
  LoadSetupData({this.activeTab = 0});
}

class SwitchSetupTab extends SetupEvent {
  final int activeTab;
  SwitchSetupTab(this.activeTab);
}

// Program Events
class CreateProgramEvent extends SetupEvent {
  final String code;
  final String name;
  CreateProgramEvent(this.code, this.name);
}

class UpdateProgramEvent extends SetupEvent {
  final int id;
  final String code;
  final String name;
  UpdateProgramEvent(this.id, this.code, this.name);
}

class DeleteProgramEvent extends SetupEvent {
  final int id;
  DeleteProgramEvent(this.id);
}

// Term Events
class CreateTermEvent extends SetupEvent {
  final String schoolYear;
  final int semester;
  CreateTermEvent(this.schoolYear, this.semester);
}

class UpdateTermEvent extends SetupEvent {
  final String id;
  final String schoolYear;
  final int semester;
  UpdateTermEvent(this.id, this.schoolYear, this.semester);
}

class DeleteTermEvent extends SetupEvent {
  final String id;
  DeleteTermEvent(this.id);
}

// Subject Events
class CreateSubjectEvent extends SetupEvent {
  final Map<String, dynamic> dto;
  CreateSubjectEvent(this.dto);
}

class UpdateSubjectEvent extends SetupEvent {
  final String id;
  final Map<String, dynamic> dto;
  UpdateSubjectEvent(this.id, this.dto);
}

class DeleteSubjectEvent extends SetupEvent {
  final String id;
  DeleteSubjectEvent(this.id);
}

class SelectSubjectForPrereqs extends SetupEvent {
  final SubjectModel? subject;
  SelectSubjectForPrereqs(this.subject);
}

class AddPrerequisiteEvent extends SetupEvent {
  final String subjectId;
  final String prerequisiteSubjectId;
  AddPrerequisiteEvent(this.subjectId, this.prerequisiteSubjectId);
}

class RemovePrerequisiteEvent extends SetupEvent {
  final String prerequisiteId;
  RemovePrerequisiteEvent(this.prerequisiteId);
}

// State
class SetupState {
  final int activeTab; // 0 = Programs, 1 = Terms, 2 = Subjects
  final bool isLoading;
  final bool isSubmitting;
  final List<AcademicProgramModel> programs;
  final List<AcademicTermModel> terms;
  final List<SubjectModel> subjects;
  final SubjectModel? selectedSubjectForPrereqs;
  final List<PrerequisiteModel> prerequisites;
  final bool isPrereqsLoading;
  final String? errorMessage;
  final String? successMessage;

  SetupState({
    this.activeTab = 0,
    this.isLoading = false,
    this.isSubmitting = false,
    this.programs = const [],
    this.terms = const [],
    this.subjects = const [],
    this.selectedSubjectForPrereqs,
    this.prerequisites = const [],
    this.isPrereqsLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  SetupState copyWith({
    int? activeTab,
    bool? isLoading,
    bool? isSubmitting,
    List<AcademicProgramModel>? programs,
    List<AcademicTermModel>? terms,
    List<SubjectModel>? subjects,
    SubjectModel? selectedSubjectForPrereqs,
    bool clearSelectedSubject = false,
    List<PrerequisiteModel>? prerequisites,
    bool? isPrereqsLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return SetupState(
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      programs: programs ?? this.programs,
      terms: terms ?? this.terms,
      subjects: subjects ?? this.subjects,
      selectedSubjectForPrereqs: clearSelectedSubject
          ? null
          : (selectedSubjectForPrereqs ?? this.selectedSubjectForPrereqs),
      prerequisites: prerequisites ?? this.prerequisites,
      isPrereqsLoading: isPrereqsLoading ?? this.isPrereqsLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

// Bloc
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  final AcademicSetupRepository _setupRepo;

  SetupBloc(this._setupRepo) : super(SetupState()) {
    on<LoadSetupData>(_onLoadSetupData);
    on<SwitchSetupTab>(_onSwitchSetupTab);
    on<CreateProgramEvent>(_onCreateProgram);
    on<UpdateProgramEvent>(_onUpdateProgram);
    on<DeleteProgramEvent>(_onDeleteProgram);
    on<CreateTermEvent>(_onCreateTerm);
    on<UpdateTermEvent>(_onUpdateTerm);
    on<DeleteTermEvent>(_onDeleteTerm);
    on<CreateSubjectEvent>(_onCreateSubject);
    on<UpdateSubjectEvent>(_onUpdateSubject);
    on<DeleteSubjectEvent>(_onDeleteSubject);
    on<SelectSubjectForPrereqs>(_onSelectSubjectForPrereqs);
    on<AddPrerequisiteEvent>(_onAddPrerequisite);
    on<RemovePrerequisiteEvent>(_onRemovePrerequisite);
  }

  Future<void> _onLoadSetupData(
      LoadSetupData event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isLoading: true, activeTab: event.activeTab, clearMessages: true));
    try {
      final results = await Future.wait([
        _setupRepo.getPrograms(),
        _setupRepo.getTerms(),
        _setupRepo.getSubjects(),
      ]);

      emit(state.copyWith(
        isLoading: false,
        programs: results[0] as List<AcademicProgramModel>,
        terms: results[1] as List<AcademicTermModel>,
        subjects: results[2] as List<SubjectModel>,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onSwitchSetupTab(SwitchSetupTab event, Emitter<SetupState> emit) {
    emit(state.copyWith(activeTab: event.activeTab, clearMessages: true));
  }

  Future<void> _onCreateProgram(
      CreateProgramEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.createProgram(code: event.code, name: event.name);
      final updated = await _setupRepo.getPrograms();
      emit(state.copyWith(
        isSubmitting: false,
        programs: updated,
        successMessage: 'Academic Program "${event.code}" created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onUpdateProgram(
      UpdateProgramEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.updateProgram(event.id,
          code: event.code, name: event.name);
      final updated = await _setupRepo.getPrograms();
      emit(state.copyWith(
        isSubmitting: false,
        programs: updated,
        successMessage: 'Academic Program "${event.code}" updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onDeleteProgram(
      DeleteProgramEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.deleteProgram(event.id);
      final updated = await _setupRepo.getPrograms();
      emit(state.copyWith(
        isSubmitting: false,
        programs: updated,
        successMessage: 'Academic Program deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onCreateTerm(
      CreateTermEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.createTerm(
          schoolYear: event.schoolYear, semester: event.semester);
      final updated = await _setupRepo.getTerms();
      emit(state.copyWith(
        isSubmitting: false,
        terms: updated,
        successMessage: 'Academic Term created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onUpdateTerm(
      UpdateTermEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.updateTerm(event.id,
          schoolYear: event.schoolYear, semester: event.semester);
      final updated = await _setupRepo.getTerms();
      emit(state.copyWith(
        isSubmitting: false,
        terms: updated,
        successMessage: 'Academic Term updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onDeleteTerm(
      DeleteTermEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.deleteTerm(event.id);
      final updated = await _setupRepo.getTerms();
      emit(state.copyWith(
        isSubmitting: false,
        terms: updated,
        successMessage: 'Academic Term deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onCreateSubject(
      CreateSubjectEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.createSubject(event.dto);
      final updated = await _setupRepo.getSubjects();
      emit(state.copyWith(
        isSubmitting: false,
        subjects: updated,
        successMessage: 'Subject created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onUpdateSubject(
      UpdateSubjectEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.updateSubject(event.id, event.dto);
      final updated = await _setupRepo.getSubjects();
      emit(state.copyWith(
        isSubmitting: false,
        subjects: updated,
        successMessage: 'Subject updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onDeleteSubject(
      DeleteSubjectEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.deleteSubject(event.id);
      final updated = await _setupRepo.getSubjects();
      emit(state.copyWith(
        isSubmitting: false,
        subjects: updated,
        successMessage: 'Subject deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onSelectSubjectForPrereqs(
      SelectSubjectForPrereqs event, Emitter<SetupState> emit) async {
    if (event.subject == null) {
      emit(state.copyWith(clearSelectedSubject: true, prerequisites: []));
      return;
    }

    emit(state.copyWith(
      selectedSubjectForPrereqs: event.subject,
      isPrereqsLoading: true,
      prerequisites: [],
      clearMessages: true,
    ));

    try {
      final list =
          await _setupRepo.getPrerequisites(event.subject!.subjectId);
      emit(state.copyWith(
        selectedSubjectForPrereqs: event.subject,
        isPrereqsLoading: false,
        prerequisites: list,
      ));
    } catch (e) {
      emit(state.copyWith(
        isPrereqsLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onAddPrerequisite(
      AddPrerequisiteEvent event, Emitter<SetupState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.addPrerequisite(
          event.subjectId, event.prerequisiteSubjectId);
      final updated =
          await _setupRepo.getPrerequisites(event.subjectId);
      emit(state.copyWith(
        isSubmitting: false,
        prerequisites: updated,
        successMessage: 'Prerequisite added successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onRemovePrerequisite(
      RemovePrerequisiteEvent event, Emitter<SetupState> emit) async {
    if (state.selectedSubjectForPrereqs == null) return;
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setupRepo.removePrerequisite(event.prerequisiteId);
      final updated = await _setupRepo
          .getPrerequisites(state.selectedSubjectForPrereqs!.subjectId);
      emit(state.copyWith(
        isSubmitting: false,
        prerequisites: updated,
        successMessage: 'Prerequisite removed successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
