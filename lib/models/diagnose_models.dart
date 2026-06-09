import '../services/perenual_api.dart';

class PlantShowcaseSeed {
  const PlantShowcaseSeed({
    required this.query,
    required this.focusLabel,
    required this.note,
    this.preferredTerms = const <String>[],
  });

  final String query;
  final String focusLabel;
  final String note;
  final List<String> preferredTerms;
}

class IssueShowcaseSeed {
  const IssueShowcaseSeed({
    required this.query,
    required this.badge,
    required this.note,
    this.aliases = const <String>[],
  });

  final String query;
  final String badge;
  final String note;
  final List<String> aliases;
}

class DiagnosePlantCard {
  const DiagnosePlantCard({
    required this.query,
    required this.focusLabel,
    required this.note,
    required this.species,
  });

  factory DiagnosePlantCard.fromCacheMap(Map<String, dynamic> map) {
    return DiagnosePlantCard(
      query: map['query'] as String? ?? '',
      focusLabel: map['focusLabel'] as String? ?? '',
      note: map['note'] as String? ?? '',
      species: PerenualSpeciesSummary.fromCacheMap(
        (map['species'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final String query;
  final String focusLabel;
  final String note;
  final PerenualSpeciesSummary species;

  String? get imageUrl => species.imageUrl ?? species.thumbnailUrl;

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'query': query,
      'focusLabel': focusLabel,
      'note': note,
      'species': species.toCacheMap(),
    };
  }
}

class DiagnoseIssueCard {
  const DiagnoseIssueCard({
    required this.query,
    required this.badge,
    required this.note,
    required this.disease,
  });

  factory DiagnoseIssueCard.fromCacheMap(Map<String, dynamic> map) {
    return DiagnoseIssueCard(
      query: map['query'] as String? ?? '',
      badge: map['badge'] as String? ?? '',
      note: map['note'] as String? ?? '',
      disease: PerenualDiseaseSummary.fromCacheMap(
        (map['disease'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final String query;
  final String badge;
  final String note;
  final PerenualDiseaseSummary disease;

  String? get imageUrl => disease.thumbnailUrl;

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'query': query,
      'badge': badge,
      'note': note,
      'disease': disease.toCacheMap(),
    };
  }
}
