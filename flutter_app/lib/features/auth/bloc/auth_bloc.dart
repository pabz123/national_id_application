import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_repository.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';

enum AuthStatus { unknown, loading, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.message,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? message;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? message,
    bool clearMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, session, message];
}

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthAppStarted extends AuthEvent {
  const AuthAppStarted();
}

class AuthSignupSubmitted extends AuthEvent {
  const AuthSignupSubmitted({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String name;
  final String email;
  final String phone;
  final String password;

  @override
  List<Object?> get props => [name, email, phone, password];
}

class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthClearMessage extends AuthEvent {
  const AuthClearMessage();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthSignupSubmitted>(_onSignupSubmitted);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthClearMessage>(_onClearMessage);
  }

  final AuthRepository _repository;

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    final session = await _repository.restoreSession();
    if (session == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticated, session: session));
  }

  Future<void> _onSignupSubmitted(
    AuthSignupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    try {
      await _repository.signup(
        name: event.name,
        email: event.email,
        phone: event.phone,
        password: event.password,
      );
      final session = await _repository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthState(
        status: AuthStatus.authenticated,
        session: session,
        message: 'Signup successful.',
      ));
    } catch (error) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearMessage: true));
    try {
      final session = await _repository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthState(
        status: AuthStatus.authenticated,
        session: session,
        message: 'Login successful.',
      ));
    } catch (error) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onClearMessage(
    AuthClearMessage event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearMessage: true));
  }
}
