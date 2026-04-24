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

class FormMetadata {
  const FormMetadata({
    required this.countries,
  });

  final List<CountryOption> countries;

  factory FormMetadata.fromJson(Map<String, dynamic> json) {
    final countriesRaw = (json['countries'] as List?) ?? const [];
    return FormMetadata(
      countries: countriesRaw
          .whereType<Map>()
          .map((item) => CountryOption.fromJson(item.cast<String, dynamic>()))
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
