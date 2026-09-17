import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/student_models.dart';
import '../repositories/student_repository.dart';
import '../utils/error_handler.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ProfileEvent {}

class LoadProfileEvent extends ProfileEvent {
  final bool refresh;
  LoadProfileEvent({this.refresh = false});
}

// ── States ───────────────────────────────────────────────────────────────────

abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final StudentProfileModel profile;
  ProfileLoaded(this.profile);
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

// ── BLoC ────────────────────────────────────────────────────────────────────

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final StudentRepository _repository;

  ProfileBloc(this._repository) : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (!event.refresh && state is! ProfileLoaded) {
      emit(ProfileLoading());
    }

    try {
      final profile = await _repository.getMyProfile();
      emit(ProfileLoaded(profile));
    } catch (e, st) {
      emit(ProfileError(getFriendlyErrorMessage(e, st)));
    }
  }
}
