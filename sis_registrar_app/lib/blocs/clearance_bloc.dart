import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/grading_models.dart';
import '../repositories/grading_repository.dart';
import '../utils/error_handler.dart';

// Events
abstract class ClearanceEvent {}

class SearchStudentsEvent extends ClearanceEvent {
  final String query;
  SearchStudentsEvent(this.query);
}

class SelectStudentEvent extends ClearanceEvent {
  final UserSearchResultModel student;
  SelectStudentEvent(this.student);
}

class ToggleClearanceEvent extends ClearanceEvent {
  final String termId;
  final bool isCleared;
  ToggleClearanceEvent(this.termId, this.isCleared);
}

class InitializeClearanceEvent extends ClearanceEvent {
  final String termId;
  final bool isCleared;
  InitializeClearanceEvent({required this.termId, this.isCleared = false});
}

// States
abstract class ClearanceState {}

class ClearanceInitial extends ClearanceState {}

class ClearanceStateData extends ClearanceState {
  final String searchQuery;
  final bool isSearching;
  final List<UserSearchResultModel> searchResults;
  final UserSearchResultModel? selectedStudent;
  final bool isClearanceLoading;
  final List<GradeClearanceModel> clearances;
  final String? togglingTermId;
  final String? errorMessage;
  final String? successMessage;

  ClearanceStateData({
    this.searchQuery = '',
    this.isSearching = false,
    this.searchResults = const [],
    this.selectedStudent,
    this.isClearanceLoading = false,
    this.clearances = const [],
    this.togglingTermId,
    this.errorMessage,
    this.successMessage,
  });

  ClearanceStateData copyWith({
    String? searchQuery,
    bool? isSearching,
    List<UserSearchResultModel>? searchResults,
    UserSearchResultModel? selectedStudent,
    bool? isClearanceLoading,
    List<GradeClearanceModel>? clearances,
    String? togglingTermId,
    bool clearToggling = false,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ClearanceStateData(
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
      selectedStudent: selectedStudent ?? this.selectedStudent,
      isClearanceLoading: isClearanceLoading ?? this.isClearanceLoading,
      clearances: clearances ?? this.clearances,
      togglingTermId: clearToggling ? null : (togglingTermId ?? this.togglingTermId),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

// Bloc with debounce
class ClearanceBloc extends Bloc<ClearanceEvent, ClearanceState> {
  final UserSearchRepository _userRepo;
  final GradeClearanceRepository _clearanceRepo;
  Timer? _debounceTimer;

  ClearanceBloc(this._userRepo, this._clearanceRepo)
      : super(ClearanceStateData()) {
    on<SearchStudentsEvent>(_onSearchStudents);
    on<SelectStudentEvent>(_onSelectStudent);
    on<ToggleClearanceEvent>(_onToggleClearance);
    on<InitializeClearanceEvent>(_onInitializeClearance);
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> _onSearchStudents(
      SearchStudentsEvent event, Emitter<ClearanceState> emit) async {
    final current = state is ClearanceStateData
        ? state as ClearanceStateData
        : ClearanceStateData();

    final completer = Completer<void>();
    _debounceTimer?.cancel();

    // Debounce ~300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      emit(current.copyWith(
        searchQuery: event.query,
        isSearching: true,
        clearMessages: true,
      ));
      try {
        final results =
            await _userRepo.search(query: event.query, role: 5);
        emit(current.copyWith(
          searchQuery: event.query,
          isSearching: false,
          searchResults: results,
        ));
      } catch (e, st) {
        emit(current.copyWith(
          searchQuery: event.query,
          isSearching: false,
          errorMessage: getFriendlyErrorMessage(e, st),
        ));
      }
      completer.complete();
    });

    await completer.future;
  }

  Future<void> _onSelectStudent(
      SelectStudentEvent event, Emitter<ClearanceState> emit) async {
    final current = state is ClearanceStateData
        ? state as ClearanceStateData
        : ClearanceStateData();

    emit(current.copyWith(
      selectedStudent: event.student,
      isClearanceLoading: true,
      clearances: [],
      clearMessages: true,
    ));

    try {
      final list =
          await _clearanceRepo.getClearancesForUser(event.student.userId);
      emit(current.copyWith(
        selectedStudent: event.student,
        isClearanceLoading: false,
        clearances: list,
      ));
    } catch (e, st) {
      emit(current.copyWith(
        selectedStudent: event.student,
        isClearanceLoading: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onToggleClearance(
      ToggleClearanceEvent event, Emitter<ClearanceState> emit) async {
    if (state is! ClearanceStateData) return;
    final current = state as ClearanceStateData;
    if (current.selectedStudent == null) return;

    emit(current.copyWith(
      togglingTermId: event.termId,
      clearMessages: true,
    ));

    try {
      final updated = await _clearanceRepo.toggleClearance(
        current.selectedStudent!.userId,
        event.termId,
        event.isCleared,
      );

      final updatedList = current.clearances.map((c) {
        if (c.termId == event.termId) {
          return updated;
        }
        return c;
      }).toList();

      emit(current.copyWith(
        clearances: updatedList,
        clearToggling: true,
        successMessage:
            'Clearance status updated to ${event.isCleared ? "Cleared" : "Hold"}!',
      ));
    } catch (e, st) {
      emit(current.copyWith(
        clearToggling: true,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }

  Future<void> _onInitializeClearance(
      InitializeClearanceEvent event, Emitter<ClearanceState> emit) async {
    if (state is! ClearanceStateData) return;
    final current = state as ClearanceStateData;
    if (current.selectedStudent == null) return;

    emit(current.copyWith(
      isClearanceLoading: true,
      clearMessages: true,
    ));

    try {
      final created = await _clearanceRepo.createClearance(
        userId: current.selectedStudent!.userId,
        termId: event.termId,
        isCleared: event.isCleared,
      );

      final updatedList = List<GradeClearanceModel>.from(current.clearances)
        ..add(created);

      emit(current.copyWith(
        clearances: updatedList,
        isClearanceLoading: false,
        successMessage: 'Grade clearance initialized successfully!',
      ));
    } catch (e, st) {
      emit(current.copyWith(
        isClearanceLoading: false,
        errorMessage: getFriendlyErrorMessage(e, st),
      ));
    }
  }
}
