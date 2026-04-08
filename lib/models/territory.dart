import 'dart:math' as math;

class Territory {
  final String id;
  final String ownerName;
  final String color;
  final double areaSqm;
  final DateTime createdAt;
  final List<List<double>> coordinates; // [lng, lat] pairs (GeoJSON order)
  bool isDeleted;

  Territory({
    required this.id,
    required this.ownerName,
    required this.color,
    required this.areaSqm,
    required this.createdAt,
    required this.coordinates,
    this.isDeleted = false,
  });

  /// Days since capture
  int get daysSinceCapture => DateTime.now().difference(createdAt).inDays;

  /// Effective area after 2%/day decay, 0% floor at 60 days
  double get effectiveArea {
    if (isExpired) return 0;
    final decayFactor = math.max(0.0, 1.0 - 0.02 * daysSinceCapture);
    return areaSqm * decayFactor;
  }

  /// Map polygon opacity — slower fade for better visibility
  double get mapOpacity {
    if (isExpired) return 0;
    return math.max(0.12, 0.4 - (daysSinceCapture * 0.007));
  }

  /// Health percentage (100% = fresh, 0% = expired)
  double get healthPercent {
    return math.max(0.0, 100.0 - (2.0 * daysSinceCapture));
  }

  /// Territory is abandoned (>30 days, very weak)
  bool get isAbandoned => daysSinceCapture >= 30;

  /// Territory has fully expired (>50 days, effectively dead)
  bool get isExpired => daysSinceCapture >= 50;

  /// GeoJSON representation for MapLibre
  Map<String, dynamic> toGeoJsonFeature() {
    return {
      "type": "Feature",
      "properties": {
        "id": id,
        "owner": ownerName,
        "color": color,
        "area": effectiveArea.toStringAsFixed(0),
        "opacity": mapOpacity,
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [coordinates],
      },
    };
  }

  factory Territory.fromMap(Map<String, dynamic> map) {
    final boundary = map['boundary'] as Map<String, dynamic>;
    final coords = (boundary['coordinates'] as List).first as List;
    return Territory(
      id: map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      ownerName: map['owner_name'] ?? 'Unknown',
      color: map['color'] ?? '#58a6ff',
      areaSqm: (map['area_sqm'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      coordinates:
          coords.map<List<double>>((c) => List<double>.from(c)).toList(),
      isDeleted: map['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_name': ownerName,
      'color': color,
      'area_sqm': areaSqm,
      'created_at': createdAt.toIso8601String(),
      'is_deleted': isDeleted,
      'boundary': {
        "type": "Polygon",
        "coordinates": [coordinates],
      },
    };
  }
}
