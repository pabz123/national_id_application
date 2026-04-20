class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8069';
  static const String databaseName = 'Odoo-Project';

  static Map<String, String> jsonHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Odoo-Database': databaseName,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
