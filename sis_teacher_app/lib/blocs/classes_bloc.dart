import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../repositories/class_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class ClassesEvent {}

class LoadMyClassesEvent extends ClassesEvent {
  final String teacherUserId;
  final String? termId;

  LoadMyClassesEvent({required this.teacherUserId, this.termId});
}

class LoadClassRosterEvent extends ClassesEvent {
  final ClassModel classItem;

  LoadClassRosterEvent(this.classItem);
}

class ClearSelectedClassEvent extends ClassesEvent {}

// States
abstract class ClassesState {}

class ClassesInitial extends ClassesState {}

class ClassesLoading extends ClassesState {}

class ClassesLoaded extends ClassesState {
  final List<ClassModel> classes;
  final ClassModel? selectedClass;
  final bool isRosterLoading;
  final List<ClassRosterItemModel> roster;
  final String? rosterError;

  ClassesLoaded({
    required this.classes,
    this.selectedClass,
    this.isRosterLoading = false,
    this.roster = const [],
    this.rosterError,
  });

  ClassesLoaded copyWith({
    List<ClassModel>? classes,
    ClassModel? selectedClass,
    bool clearSelectedClass = false,
    bool? isRosterLoading,
    List<ClassRosterItemModel>? roster,
    String? rosterError,
    bool clearRosterError = false,
  }) {
    return ClassesLoaded(
      classes: classes ?? this.classes,
      selectedClass: clearSelectedClass ? null : (selectedClass ?? this.selectedClass),
      isRosterLoading: isRosterLoading ?? this.isRosterLoading,
      roster: roster ?? this.roster,
      rosterError: clearRosterError ? null : (rosterError ?? this.rosterError),
    );
  }
}

class ClassesError extends ClassesState {
  final String message;

  ClassesError(this.message);
}

// Bloc
class ClassesBloc extends Bloc<ClassesEvent, ClassesState> {
  final ClassRepository _classRepo;

  ClassesBloc(this._classRepo) : super(ClassesInitial()) {
    on<LoadMyClassesEvent>(_onLoadMyClasses);
    on<LoadClassRosterEvent>(_onLoadClassRoster);
    on<ClearSelectedClassEvent>(_onClearSelectedClass);
  }

  Future<void> _onLoadMyClasses(
      LoadMyClassesEvent event, Emitter<ClassesState> emit) async {
    emit(ClassesLoading());
    try {
      final classes = await _classRepo.getMyClasses(
        teacherUserId: event.teacherUserId,
        termId: event.termId,
      );
      emit(ClassesLoaded(classes: classes));
    } catch (e, st) {
      emit(ClassesError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onLoadClassRoster(
      LoadClassRosterEvent event, Emitter<ClassesState> emit) async {
    if (state is! ClassesLoaded) return;
    final current = state as ClassesLoaded;

    emit(current.copyWith(
      selectedClass: event.classItem,
      isRosterLoading: true,
      clearRosterError: true,
      roster: const [],
    ));

    try {
      final roster = await _classRepo.getClassRoster(event.classItem.classId);
      emit(current.copyWith(
        selectedClass: event.classItem,
        isRosterLoading: false,
        roster: roster,
      ));
    } catch (e, st) {
      emit(current.copyWith(
        selectedClass: event.classItem,
        isRosterLoading: false,
        rosterError: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  void _onClearSelectedClass(
      ClearSelectedClassEvent event, Emitter<ClassesState> emit) {
    if (state is! ClassesLoaded) return;
    final current = state as ClassesLoaded;
    emit(current.copyWith(
      clearSelectedClass: true,
      roster: const [],
      isRosterLoading: false,
      clearRosterError: true,
    ));
  }
}
