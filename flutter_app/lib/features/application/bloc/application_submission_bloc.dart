// features/application/bloc/application_submission_bloc.dart
// FIXED: clears state properly so re-navigation after success doesn't
// show a stale "already submitted" banner on a fresh session.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/application/data/application_repository.dart';
import 'package:national_id_flutter_app/features/application/data/form_metadata.dart';

enum ApplicationSubmissionStatus { initial, loading, success, failure }

class ApplicationSubmissionState extends Equatable {
  const ApplicationSubmissionState({
    this.status = ApplicationSubmissionStatus.initial,
    this.result,
    this.message,
  });

  final ApplicationSubmissionStatus status;
  final ApplicationSubmissionResult? result;
  final String? message;

  ApplicationSubmissionState copyWith({
    ApplicationSubmissionStatus? status,
    ApplicationSubmissionResult? result,
    String? message,
    bool clearMessage = false,
    bool clearResult = false,
  }) {
    return ApplicationSubmissionState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, result, message];
}

abstract class ApplicationSubmissionEvent extends Equatable {
  const ApplicationSubmissionEvent();
  @override
  List<Object?> get props => [];
}

class ApplicationSubmitRequested extends ApplicationSubmissionEvent {
  const ApplicationSubmitRequested({
    required this.token,
    required this.request,
  });

  final String token;
  final ApplicationFormRequest request;

  @override
  List<Object?> get props => [token, request];
}

class ApplicationSubmissionReset extends ApplicationSubmissionEvent {
  const ApplicationSubmissionReset();
}

class ApplicationSubmissionBloc
    extends Bloc<ApplicationSubmissionEvent, ApplicationSubmissionState> {
  ApplicationSubmissionBloc({required ApplicationRepository repository})
      : _repository = repository,
        super(const ApplicationSubmissionState()) {
    on<ApplicationSubmitRequested>(_onSubmitRequested);
    on<ApplicationSubmissionReset>(_onReset);
  }

  final ApplicationRepository _repository;

  Future<void> _onSubmitRequested(
    ApplicationSubmitRequested event,
    Emitter<ApplicationSubmissionState> emit,
  ) async {
    // Guard: if already succeeded (within same session), don't resubmit.
    if (state.status == ApplicationSubmissionStatus.success) return;

    emit(state.copyWith(
      status: ApplicationSubmissionStatus.loading,
      clearMessage: true,
      clearResult: true,
    ));
    try {
      final result = await _repository.submitApplication(
        token: event.token,
        request: event.request,
      );
      emit(ApplicationSubmissionState(
        status: ApplicationSubmissionStatus.success,
        result: result,
        message: 'Application submitted successfully.',
      ));
    } catch (error) {
      emit(ApplicationSubmissionState(
        status: ApplicationSubmissionStatus.failure,
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onReset(
    ApplicationSubmissionReset event,
    Emitter<ApplicationSubmissionState> emit,
  ) {
    emit(const ApplicationSubmissionState());
  }
}
