import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/data/tracking_repository.dart';

enum TrackingStatus { initial, loading, success, failure }

class TrackingState extends Equatable {
  const TrackingState({
    this.status = TrackingStatus.initial,
    this.application,
    this.message,
  });

  final TrackingStatus status;
  final TrackingApplication? application;
  final String? message;

  TrackingState copyWith({
    TrackingStatus? status,
    TrackingApplication? application,
    String? message,
    bool clearMessage = false,
    bool clearApplication = false,
  }) {
    return TrackingState(
      status: status ?? this.status,
      application: clearApplication ? null : (application ?? this.application),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, application, message];
}

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

class TrackingRequested extends TrackingEvent {
  const TrackingRequested(this.reference);

  final String reference;

  @override
  List<Object?> get props => [reference];
}

class TrackingReset extends TrackingEvent {
  const TrackingReset();
}

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc({required TrackingRepository repository})
      : _repository = repository,
        super(const TrackingState()) {
    on<TrackingRequested>(_onTrackingRequested);
    on<TrackingReset>(_onTrackingReset);
  }

  final TrackingRepository _repository;

  Future<void> _onTrackingRequested(
    TrackingRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(state.copyWith(
      status: TrackingStatus.loading,
      clearMessage: true,
      clearApplication: true,
    ));
    try {
      final application = await _repository.trackApplication(event.reference);
      emit(TrackingState(
        status: TrackingStatus.success,
        application: application,
      ));
    } catch (error) {
      emit(TrackingState(
        status: TrackingStatus.failure,
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onTrackingReset(
    TrackingReset event,
    Emitter<TrackingState> emit,
  ) {
    emit(const TrackingState());
  }
}
