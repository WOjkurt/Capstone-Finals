import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/staff_model.dart';
import '../repositories/staff_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class StaffEvent {}

class LoadStaffList extends StaffEvent {}

class CreateStaffEvent extends StaffEvent {
  final CreateStaffRequest request;
  CreateStaffEvent(this.request);
}

class DisableStaffEvent extends StaffEvent {
  final String id;
  DisableStaffEvent(this.id);
}

class ReactivateStaffEvent extends StaffEvent {
  final String id;
  ReactivateStaffEvent(this.id);
}

class UpdateStaffEvent extends StaffEvent {
  final String id;
  final UpdateStaffRequest request;
  UpdateStaffEvent(this.id, this.request);
}

class ClearStaffCreatedEvent extends StaffEvent {}

class ClearStaffUpdatedEvent extends StaffEvent {}

class ClearStaffMessagesEvent extends StaffEvent {}

// State
class StaffState {
  final bool isLoading;
  final bool isSubmitting;
  final String? processingId;
  final List<StaffModel> staffList;
  final StaffModel? createdStaff;
  final StaffModel? updatedStaff;
  final String? errorMessage;
  final String? successMessage;
  final String? warningMessage;

  StaffState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.processingId,
    this.staffList = const [],
    this.createdStaff,
    this.updatedStaff,
    this.errorMessage,
    this.successMessage,
    this.warningMessage,
  });

  StaffState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? processingId,
    bool clearProcessing = false,
    List<StaffModel>? staffList,
    StaffModel? createdStaff,
    bool clearCreatedStaff = false,
    StaffModel? updatedStaff,
    bool clearUpdatedStaff = false,
    String? errorMessage,
    String? successMessage,
    String? warningMessage,
    bool clearMessages = false,
  }) {
    return StaffState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      processingId: clearProcessing
          ? null
          : (processingId ?? this.processingId),
      staffList: staffList ?? this.staffList,
      createdStaff: clearCreatedStaff
          ? null
          : (createdStaff ?? this.createdStaff),
      updatedStaff: clearUpdatedStaff
          ? null
          : (updatedStaff ?? this.updatedStaff),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
      warningMessage:
          clearMessages ? null : (warningMessage ?? this.warningMessage),
    );
  }
}

// Bloc
class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final StaffRepository _staffRepository;

  StaffBloc(this._staffRepository) : super(StaffState()) {
    on<LoadStaffList>(_onLoadStaffList);
    on<CreateStaffEvent>(_onCreateStaff);
    on<UpdateStaffEvent>(_onUpdateStaff);
    on<DisableStaffEvent>(_onDisableStaff);
    on<ReactivateStaffEvent>(_onReactivateStaff);
    on<ClearStaffCreatedEvent>((event, emit) {
      emit(state.copyWith(clearCreatedStaff: true));
    });
    on<ClearStaffUpdatedEvent>((event, emit) {
      emit(state.copyWith(clearUpdatedStaff: true));
    });
    on<ClearStaffMessagesEvent>((event, emit) {
      emit(state.copyWith(clearMessages: true));
    });
  }

  Future<void> _onLoadStaffList(
      LoadStaffList event, Emitter<StaffState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    try {
      final list = await _staffRepository.getAllStaff();
      emit(state.copyWith(isLoading: false, staffList: list));
    } catch (e, st) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onCreateStaff(
      CreateStaffEvent event, Emitter<StaffState> emit) async {
    emit(state.copyWith(
      isSubmitting: true,
      clearMessages: true,
      clearCreatedStaff: true,
    ));
    try {
      final created = await _staffRepository.createStaff(event.request);
      final updatedList = await _staffRepository.getAllStaff();
      emit(state.copyWith(
        isSubmitting: false,
        staffList: updatedList,
        createdStaff: created,
        successMessage: 'Staff account created successfully for ${created.fullName}!',
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onUpdateStaff(
      UpdateStaffEvent event, Emitter<StaffState> emit) async {
    emit(state.copyWith(
      isSubmitting: true,
      clearMessages: true,
      clearUpdatedStaff: true,
    ));
    try {
      final updated = await _staffRepository.updateStaff(event.id, event.request);
      final list = state.staffList.map((s) {
        return s.userId == event.id ? updated : s;
      }).toList();
      emit(state.copyWith(
        isSubmitting: false,
        staffList: list,
        updatedStaff: updated,
        warningMessage: updated.firebaseSyncWarning,
        successMessage: 'Staff account for ${updated.fullName} updated successfully.',
      ));
    } catch (e, st) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onDisableStaff(
      DisableStaffEvent event, Emitter<StaffState> emit) async {
    emit(state.copyWith(
      processingId: event.id,
      clearMessages: true,
    ));
    try {
      final updated = await _staffRepository.disableStaff(event.id);
      final list = state.staffList.map((s) {
        return s.userId == event.id ? updated : s;
      }).toList();
      emit(state.copyWith(
        clearProcessing: true,
        staffList: list,
        successMessage: 'Staff account for ${updated.fullName} has been disabled.',
      ));
    } catch (e, st) {
      emit(state.copyWith(
        clearProcessing: true,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onReactivateStaff(
      ReactivateStaffEvent event, Emitter<StaffState> emit) async {
    emit(state.copyWith(
      processingId: event.id,
      clearMessages: true,
    ));
    try {
      final updated = await _staffRepository.reactivateStaff(event.id);
      final list = state.staffList.map((s) {
        return s.userId == event.id ? updated : s;
      }).toList();
      emit(state.copyWith(
        clearProcessing: true,
        staffList: list,
        successMessage: 'Staff account for ${updated.fullName} has been reactivated.',
      ));
    } catch (e, st) {
      emit(state.copyWith(
        clearProcessing: true,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }
}
