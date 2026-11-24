import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/staff_model.dart';
import '../repositories/staff_repository.dart';
import '../utils/error_handler.dart';

/// Emails a link for setting a password. Firebase sends the message itself, so nothing
/// here talks to a mail server.
typedef SendPasswordReset = Future<void> Function(String email);

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

  /// Whether the setup link was emailed to the account just created. False means the
  /// email did not go out and the Registrar has to send the link themselves.
  final bool createdStaffEmailSent;
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
    this.createdStaffEmailSent = false,
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
    bool? createdStaffEmailSent,
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
      createdStaffEmailSent: clearCreatedStaff
          ? false
          : (createdStaffEmailSent ?? this.createdStaffEmailSent),
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
  final SendPasswordReset _sendPasswordReset;

  StaffBloc(this._staffRepository, {required SendPasswordReset sendPasswordReset})
      : _sendPasswordReset = sendPasswordReset,
        super(StaffState()) {
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

      // Firebase emails the setup link itself. If that fails the account is still good:
      // the dialog falls back to the link, for the Registrar to pass on by hand.
      var emailSent = false;
      try {
        await _sendPasswordReset(created.email);
        emailSent = true;
      } catch (_) {
        emailSent = false;
      }

      final updatedList = await _staffRepository.getAllStaff();
      emit(state.copyWith(
        isSubmitting: false,
        staffList: updatedList,
        createdStaff: created,
        createdStaffEmailSent: emailSent,
        successMessage: emailSent
            ? 'Staff account created for ${created.fullName}. The setup link was emailed to ${created.email}.'
            : 'Staff account created for ${created.fullName}, but the setup link could not be emailed — send it to them yourself.',
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
