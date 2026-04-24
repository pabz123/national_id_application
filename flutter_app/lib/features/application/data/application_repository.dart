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
    required this.nextOfKinName,
    required this.nextOfKinPhone,
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
  final String nextOfKinName;
  final String nextOfKinPhone;
  final int? districtId;
  final String? existingNin;
}

class ApplicationRepository {
  ApplicationRepository({required http.Client client}) : _client = client;
  final http.Client _client;

  Future<FormMetadata> fetchMetadata() async {
    final uri = ApiConfig.buildUri('/api/mobile/metadata');
    final response = await _client
        .get(uri, headers: ApiConfig.jsonHeaders())
        .timeout(ApiConfig.requestTimeout,
            onTimeout: () => throw Exception(
                'Metadata timed out. Check API URL.'));
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
    final uri = ApiConfig.buildUri('/api/mobile/application/submit');
    final mp = http.MultipartRequest('POST', uri);
    mp.headers['Authorization'] = 'Bearer $token';
    mp.fields.addAll({
      'full_name': request.fullName.trim(),
      'date_of_birth': request.dateOfBirth.trim(),
      'gender': request.gender,
      'nationality_id': request.nationalityId.toString(),
      'district_name': request.districtName.trim(),
      'phone': request.phone.trim(),
      'email': request.email.trim(),
      'existing_nin': (request.existingNin ?? '').trim(),
      'district_id': request.districtId?.toString() ?? '',
      'next_of_kin_name': request.nextOfKinName.trim(),
      'next_of_kin_phone': request.nextOfKinPhone.trim(),
    });
    mp.files.add(await _toFile('photo', request.photoFile));
    mp.files.add(await _toFile('lc_letter', request.lcLetterFile));

    final streamed = await mp.send().timeout(ApiConfig.requestTimeout,
        onTimeout: () =>
            throw Exception('Submission timed out. Check API URL.'));
    final response = await http.Response.fromStream(streamed);
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(_extractError(data, fallback: 'Submission failed.'));
    }
    return ApplicationSubmissionResult(
      reference: (data['reference'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
    );
  }

  Future<http.MultipartFile> _toFile(String field, PlatformFile f) async {
    if (f.bytes != null) {
      return http.MultipartFile.fromBytes(field, f.bytes!, filename: f.name);
    }
    if (f.path != null && f.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(field, f.path!);
    }
    throw Exception('Cannot read file: ${f.name}');
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return const {};
  }

  String _extractError(Map<String, dynamic> data, {required String fallback}) {
    final msg = data['message']?.toString().trim() ?? '';
    return msg.isNotEmpty ? msg : fallback;
  }
}
