import 'package:cloud_firestore/cloud_firestore.dart';

class GardenPlant {
  const GardenPlant({
    this.id = '',
    String? scientificName,
    double? score,
    this.name,
    this.commonNames = const <String>[],
    this.imageUrl,
    this.localImagePath,
    DateTime? createdAt,
    DateTime? lastScannedAt,
    DateTime? dateAdded,
    this.lastWatered,
    this.healthStatus,
  })  : scientificName = scientificName ?? name ?? 'Unknown',
        score = score ?? 0,
        createdAt = createdAt ?? dateAdded,
        lastScannedAt = lastScannedAt;

  final String id;
  final String? name;
  final String scientificName;
  final double score;
  final List<String> commonNames;
  final String? imageUrl;
  final String? localImagePath;
  final DateTime? createdAt;
  final DateTime? lastScannedAt;
  final DateTime? lastWatered;
  final String? healthStatus;

  String get displayName =>
      name ?? (commonNames.isNotEmpty ? commonNames.first : scientificName);

  String get confidenceLabel =>
      '${(score.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%';

  DateTime? get dateAdded => createdAt;

  factory GardenPlant.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return GardenPlant.fromMap(document.data() ?? const <String, dynamic>{}, id: document.id);
  }

  factory GardenPlant.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return GardenPlant(
      id: id,
      name: map['name'] as String?,
      scientificName: map['scientificName'] as String? ?? 'Unknown',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      commonNames: (map['commonNames'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(),
      imageUrl: map['imageUrl'] as String?,
      localImagePath: map['localImagePath'] as String?,
      createdAt: _dateTimeFromValue(map['createdAt']),
      lastScannedAt: _dateTimeFromValue(map['lastScannedAt']),
      lastWatered: _dateTimeFromValue(map['lastWatered']),
      healthStatus: map['healthStatus'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'scientificName': scientificName,
      'score': score,
      'commonNames': commonNames,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'createdAt': createdAt,
      'lastScannedAt': lastScannedAt,
      'lastWatered': lastWatered,
      'healthStatus': healthStatus,
    };
  }

  GardenPlant copyWith({
    String? id,
    String? name,
    String? scientificName,
    double? score,
    List<String>? commonNames,
    String? imageUrl,
    String? localImagePath,
    DateTime? createdAt,
    DateTime? lastScannedAt,
    DateTime? lastWatered,
    String? healthStatus,
  }) {
    return GardenPlant(
      id: id ?? this.id,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      score: score ?? this.score,
      commonNames: commonNames ?? this.commonNames,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      createdAt: createdAt ?? this.createdAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      lastWatered: lastWatered ?? this.lastWatered,
      healthStatus: healthStatus ?? this.healthStatus,
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
