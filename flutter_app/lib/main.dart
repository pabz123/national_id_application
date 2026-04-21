import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:national_id_flutter_app/core/storage/session_storage.dart';
import 'package:national_id_flutter_app/features/application/bloc/application_submission_bloc.dart';
import 'package:national_id_flutter_app/features/application/data/application_repository.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_repository.dart';
import 'package:national_id_flutter_app/features/auth/presentation/auth_gate_screen.dart';
import 'package:national_id_flutter_app/features/home/presentation/home_screen.dart';
import 'package:national_id_flutter_app/features/tracking/bloc/tracking_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/data/tracking_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final httpClient = http.Client();
  final sessionStorage = SessionStorage();

  runApp(NationalIdApp(
    authRepository: AuthRepository(
      client: httpClient,
      storage: sessionStorage,
    ),
    applicationRepository: ApplicationRepository(client: httpClient),
    trackingRepository: TrackingRepository(client: httpClient),
  ));
}

class NationalIdApp extends StatelessWidget {
  const NationalIdApp({
    required this.authRepository,
    required this.applicationRepository,
    required this.trackingRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final ApplicationRepository applicationRepository;
  final TrackingRepository trackingRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: applicationRepository),
        RepositoryProvider.value(value: trackingRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              repository: context.read<AuthRepository>(),
            )..add(const AuthAppStarted()),
          ),
          BlocProvider(
            create: (context) => ApplicationSubmissionBloc(
              repository: context.read<ApplicationRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => TrackingBloc(
              repository: context.read<TrackingRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'National ID Mobile',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0C3D28),
              brightness: Brightness.light,
              background: const Color(0xFFFFFFFF),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              backgroundColor: Color(0xFF0C3D28),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8EFE8), width: 1),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFAFCFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDEE8E2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0C3D28), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C3D28),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
          ),
          home: const _AppEntryPoint(),
        ),
      ),
    );
  }
}

class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return HomeScreen(session: state.session!);
          case AuthStatus.unauthenticated:
            return const AuthGateScreen();
          case AuthStatus.loading:
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}
