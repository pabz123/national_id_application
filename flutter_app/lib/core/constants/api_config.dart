class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8069',
  );
  static const String databaseName = 'Odoo-Project';
  static const Duration requestTimeout = Duration(seconds: 20);

  static Map<String, String> jsonHeaders({String? token}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final base = Uri.parse('$baseUrl$path');
    return base.replace(
      queryParameters: {
        'db': databaseName,
        ...?queryParameters,
      },
    );
  }
}
