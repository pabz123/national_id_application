class CountryOption {
  const CountryOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory CountryOption.fromJson(Map<String, dynamic> json) {
    return CountryOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}

class DistrictOption {
  const DistrictOption({
    required this.id,
    required this.name,
    required this.countryId,
  });

  final int id;
  final String name;
  final int? countryId;

  factory DistrictOption.fromJson(Map<String, dynamic> json) {
    return DistrictOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      countryId: (json['country_id'] as num?)?.toInt(),
    );
  }
}

class FormMetadata {
  const FormMetadata({
    required this.countries,
    required this.districts,
  });

  final List<CountryOption> countries;
  final List<DistrictOption> districts;

  factory FormMetadata.fromJson(Map<String, dynamic> json) {
    final countriesRaw = (json['countries'] as List?) ?? const [];
    final districtsRaw = (json['districts'] as List?) ?? const [];
    return FormMetadata(
      countries: countriesRaw
          .whereType<Map>()
          .map((item) => CountryOption.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      districts: districtsRaw
          .whereType<Map>()
          .map((item) => DistrictOption.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class ApplicationSubmissionResult {
  const ApplicationSubmissionResult({
    required this.reference,
    required this.status,
  });

  final String reference;
  final String status;
}
