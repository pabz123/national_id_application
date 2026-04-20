import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:national_id_flutter_app/core/constants/api_config.dart';
import 'package:national_id_flutter_app/features/application/data/form_metadata.dart';

class ApplicationFormRequest {
  const ApplicationFormRequest({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.nationalityId,
    required this.districtName,
    required this.phone,
    required this.email,
    required this.photoFile,
    required this.lcLetterFile,
    this.districtId,
    this.existingNin,
  });

  final String fullName;
  final String dateOfBirth;
  final String gender;
  final int nationalityId;
  final String districtName;
  final String phone;
  final String email;
  final PlatformFile photoFile;
  final PlatformFile lcLetterFile;
  final int? districtId;
  final String? existingNin;
}

class ApplicationRepository {
  ApplicationRepository({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<FormMetadata> fetchMetadata() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/metadata');
    final response = await _client.get(
      uri,
      headers: ApiConfig.jsonHeaders(),
    );
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractError(data, fallback: 'Failed to load form metadata.'));
    }
    return FormMetadata.fromJson(data);
  }

  Future<ApplicationSubmissionResult> submitApplication({
    required String token,
    required ApplicationFormRequest request,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/application/submit');
    final multipartRequest = http.MultipartRequest('POST', uri);
    multipartRequest.headers.addAll({
      'X-Odoo-Database': ApiConfig.databaseName,
      'Authorization': 'Bearer $token',
    });
    multipartRequest.fields.addAll({
      'full_name': request.fullName.trim(),
      'date_of_birth': request.dateOfBirth.trim(),
      'gender': request.gender,
      'nationality_id': request.nationalityId.toString(),
      'district_name': request.districtName.trim(),
      'phone': request.phone.trim(),
      'email': request.email.trim(),
      'existing_nin': (request.existingNin ?? '').trim(),
      'district_id': request.districtId?.toString() ?? '',
    });

    multipartRequest.files.add(await _toMultipartFile('photo', request.photoFile));
    multipartRequest.files
        .add(await _toMultipartFile('lc_letter', request.lcLetterFile));

    final streamed = await multipartRequest.send();
    final response = await http.Response.fromStream(streamed);
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractError(data, fallback: 'Application submission failed.'));
    }
    return ApplicationSubmissionResult(
      reference: (data['reference'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
    );
  }

  Future<http.MultipartFile> _toMultipartFile(
    String fieldName,
    PlatformFile file,
  ) async {
    if (file.bytes != null) {
      return http.MultipartFile.fromBytes(
        fieldName,
        file.bytes!,
        filename: file.name,
      );
    }
    if (file.path != null && file.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(fieldName, file.path!);
    }
    throw Exception('Unable to read selected file: ${file.name}');
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Use fallback.
    }
    return const <String, dynamic>{};
  }

  String _extractError(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = data['message']?.toString().trim() ?? '';
    return message.isNotEmpty ? message : fallback;
  }
}
