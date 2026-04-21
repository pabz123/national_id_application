import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:national_id_flutter_app/core/constants/api_config.dart';

class TrackingStage {
  const TrackingStage({
    required this.code,
    required this.label,
    required this.completed,
  });

  final String code;
  final String label;
  final bool completed;

  factory TrackingStage.fromJson(Map<String, dynamic> json) {
    return TrackingStage(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      completed: json['completed'] == true,
    );
  }
}

class TrackingApplication {
  const TrackingApplication({
    required this.reference,
    required this.fullName,
    required this.statusCode,
    required this.statusLabel,
    required this.timeline,
    required this.rejectionReason,
    required this.decisionReason,
    required this.nextStepRecommendation,
  });

  final String reference;
  final String fullName;
  final String statusCode;
  final String statusLabel;
  final List<TrackingStage> timeline;
  final String rejectionReason;
  final String decisionReason;
  final String nextStepRecommendation;

  factory TrackingApplication.fromJson(Map<String, dynamic> json) {
    final timelineRaw = (json['timeline'] as List?) ?? const [];
    return TrackingApplication(
      reference: (json['reference'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      statusCode: (json['status_code'] ?? '').toString(),
      statusLabel: (json['status'] ?? '').toString(),
      rejectionReason: (json['rejection_reason'] ?? '').toString(),
      decisionReason: (json['decision_reason'] ?? '').toString(),
      nextStepRecommendation:
          (json['next_step_recommendation'] ?? '').toString(),
      timeline: timelineRaw
          .whereType<Map>()
          .map((item) => TrackingStage.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class TrackingRepository {
  TrackingRepository({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<TrackingApplication> trackApplication(String reference) async {
    final cleanReference = reference.trim();
    if (cleanReference.isEmpty) {
      throw Exception('Tracking number is required.');
    }
    final uri = ApiConfig.buildUri(
      '/api/mobile/application/track',
      queryParameters: {'reference': cleanReference},
    );
    final response = await _client.get(
      uri,
      headers: ApiConfig.jsonHeaders(),
    );
    final data = _decodeJson(response.body);
    if (response.statusCode >= 400 || data['success'] != true) {
      throw Exception(
          _extractError(data, fallback: 'Unable to track application.'));
    }
    final applicationMap =
        (data['application'] as Map?)?.cast<String, dynamic>() ?? {};
    return TrackingApplication.fromJson(applicationMap);
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
