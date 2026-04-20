import 'package:national_id_flutter_app/features/auth/data/auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AuthUser user;
}
