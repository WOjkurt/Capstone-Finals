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

// States
abstract class ScheduleState {}

class ScheduleInitial extends ScheduleState {}

class ScheduleLoading extends ScheduleState {}

class ScheduleLoaded extends ScheduleState {
  final AcademicTermModel? activeTerm;
  final List<StudentScheduleItemModel> items;
  final double totalUnits;

  ScheduleLoaded({
    required this.activeTerm,
    required this.items,
  }) : totalUnits = items.where((i) => i.isEnrolled).fold(0.0, (sum, i) => sum + i.units);

  List<StudentScheduleItemModel> get enrolledItems =>
      items.where((i) => i.isEnrolled).toList();

  List<StudentScheduleItemModel> get pendingItems =>
      items.where((i) => i.isPending).toList();
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
  }

  Future<void> _onLoadSchedule(
    LoadScheduleEvent event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleLoading());
    try {
      final activeTerm = await _repository.getActiveTerm();
      if (activeTerm == null) {
        emit(ScheduleLoaded(activeTerm: null, items: const []));
        return;
      }

      final items = await _repository.getMySchedule(
        event.userId,
        activeTerm.termId,
      );
      emit(ScheduleLoaded(activeTerm: activeTerm, items: items));
    } catch (e, st) {
      emit(ScheduleError(getFriendlyErrorMessage(e, st)));
    }
  }
}
