import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:national_id_flutter_app/core/constants/api_config.dart';
import 'package:national_id_flutter_app/core/storage/session_storage.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_user.dart';

class AuthRepository {
  AuthRepository({
    required http.Client client,
    required SessionStorage storage,
  })  : _client = client,
        _storage = storage;

  final http.Client _client;
  final SessionStorage _storage;

  Future<void> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uri = ApiConfig.buildUri('/api/mobile/signup');
    final response = await _client.post(
      uri,
      headers: const {'Accept': 'application/json'},
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      },
    ).timeout(
      ApiConfig.requestTimeout,
      onTimeout: () => throw Exception(
        'Signup timed out. Check API URL or backend server status.',
      ),
    );
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, fallback: 'Signup failed.'));
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final uri = ApiConfig.buildUri('/api/mobile/login');
    final response = await _client.post(
      uri,
      headers: const {'Accept': 'application/json'},
      body: {
        'email': email.trim(),
        'password': password,
      },
    ).timeout(
      ApiConfig.requestTimeout,
      onTimeout: () => throw Exception(
        'Login timed out. Check API URL or backend server status.',
      ),
    );
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractErrorMessage(data, fallback: 'Login failed.'));
    }

    final token = (data['token'] ?? '').toString();
    final user = AuthUser.fromJson((data['user'] as Map?)?.cast<String, dynamic>() ?? {});
    if (token.isEmpty) {
      throw Exception('Login failed: missing session token.');
    }

    await _storage.saveSession(
      token: token,
      name: user.name,
      email: user.email,
      phone: user.phone,
    );
    return AuthSession(token: token, user: user);
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _storage.getToken();
    final profile = await _storage.getUserProfile();
    if (token == null || profile == null) {
      return null;
    }
    return AuthSession(
      token: token,
      user: AuthUser(
        name: profile['name'] ?? '',
        email: profile['email'] ?? '',
        phone: profile['phone'] ?? '',
      ),
    );
  }

  Future<void> logout() => _storage.clearSession();

  Map<String, dynamic> _decodeJson(String body) {
    final text = body.trimLeft();
    if (text.startsWith('<!DOCTYPE') || text.startsWith('<html')) {
      return <String, dynamic>{
        'message': 'Backend returned an HTML page. Confirm Odoo is running and API_BASE_URL/db are correct.'
      };
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Handled by fallback error below.
    }
    return const <String, dynamic>{};
  }

  String _extractErrorMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = data['message']?.toString().trim() ?? '';
    return message.isNotEmpty ? message : fallback;
  }
}
