import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/class_models.dart';
import '../models/setup_models.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class ScheduleEvent {}

class LoadScheduleEvent extends ScheduleEvent {
  final String userId;
  final bool refresh;

  LoadScheduleEvent({
    required this.userId,
    this.refresh = false,
  });
}

class SelectScheduleTermEvent extends ScheduleEvent {
  final AcademicTermModel term;
  final String userId;

  SelectScheduleTermEvent({
    required this.term,
    required this.userId,
  });
}

// States
abstract class ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleLoaded extends ScheduleState {
  final List<AcademicTermModel> terms;

  /// The term whose schedule is shown. Same object instance as an element
  /// of [terms] whenever possible, so the header dropdown can match it.
  final AcademicTermModel? selectedTerm;
  final AcademicTermModel? activeTerm;
  final List<StudentScheduleItemModel> items;
  final bool isTermLoading;
  final double totalUnits;

  ScheduleLoaded({
    this.terms = const [],
    this.selectedTerm,
    required this.activeTerm,
    required this.items,
    this.isTermLoading = false,
  }) : totalUnits = items.where((i) => i.isEnrolled).fold(0.0, (sum, i) => sum + i.units);

  List<StudentScheduleItemModel> get enrolledItems =>
      items.where((i) => i.isEnrolled).toList();

  List<StudentScheduleItemModel> get pendingItems =>
      items.where((i) => i.isPending).toList();

  ScheduleLoaded copyWith({
    List<AcademicTermModel>? terms,
    AcademicTermModel? selectedTerm,
    AcademicTermModel? activeTerm,
    List<StudentScheduleItemModel>? items,
    bool? isTermLoading,
  }) {
    return ScheduleLoaded(
      terms: terms ?? this.terms,
      selectedTerm: selectedTerm ?? this.selectedTerm,
      activeTerm: activeTerm ?? this.activeTerm,
      items: items ?? this.items,
      isTermLoading: isTermLoading ?? this.isTermLoading,
    );
  }
}

class ScheduleError extends ScheduleState {
  final String message;

  ScheduleError(this.message);
}

// BLoC
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final StudentRepository _repository;

  ScheduleBloc(this._repository) : super(ScheduleInitial()) {
    on<LoadScheduleEvent>(_onLoadSchedule);
    on<SelectScheduleTermEvent>(_onSelectScheduleTerm);
  }

  Future<void> _onLoadSchedule(
    LoadScheduleEvent event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleLoading());
    try {
      final results = await Future.wait([
        _repository.getAllTerms(),
        _repository.getActiveTerm(),
      ]);

      final terms = results[0] as List<AcademicTermModel>;
      final activeTerm = results[1] as AcademicTermModel?;

      AcademicTermModel? selectedTerm;
      if (activeTerm != null) {
        selectedTerm = terms.firstWhere(
          (t) => t.termId == activeTerm.termId,
          orElse: () => activeTerm,
        );
      } else if (terms.isNotEmpty) {
        selectedTerm = terms.first;
      }

      if (selectedTerm == null) {
        emit(ScheduleLoaded(
          terms: terms,
          selectedTerm: null,
          activeTerm: activeTerm,
          items: const [],
        ));
        return;
      }

      final items = await _repository.getMySchedule(
        event.userId,
        selectedTerm.termId,
      );
      emit(ScheduleLoaded(
        terms: terms,
        selectedTerm: selectedTerm,
        activeTerm: activeTerm,
        items: items,
      ));
    } catch (e, st) {
      emit(ScheduleError(getFriendlyErrorMessage(e, st)));
    }
  }

  Future<void> _onSelectScheduleTerm(
    SelectScheduleTermEvent event,
    Emitter<ScheduleState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ScheduleLoaded) return;

    if (currentState.selectedTerm?.termId == event.term.termId &&
        !currentState.isTermLoading) {
      return;
    }

    emit(currentState.copyWith(
      selectedTerm: event.term,
      isTermLoading: true,
    ));

    try {
      final items = await _repository.getMySchedule(
        event.userId,
        event.term.termId,
      );
      emit(currentState.copyWith(
        selectedTerm: event.term,
        items: items,
        isTermLoading: false,
      ));
    } catch (e, st) {
      emit(ScheduleError(getFriendlyErrorMessage(e, st)));
    }
  }
}
