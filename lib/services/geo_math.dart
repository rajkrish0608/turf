import 'dart:math' as math;
import 'package:flutter/painting.dart' show HSLColor;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Capture validation results
enum CaptureValidation {
  valid,
  tooFewPoints,
  tooShort,
  areaTooSmall,
  areaTooLarge,
  tooFast,
  notALoop,
  teleportDetected,
}

/// Result of territory overlap check
enum OverlapResult {
  independent, // <10% overlap — both territories coexist
  contested, // 10-50% overlap — existing territory loses overlap area
  stolen, // >50% overlap — new player takes over
}

/// Thrown when capture validation fails
class CaptureException implements Exception {
  final String message;
  final CaptureValidation validation;

  const CaptureException(this.message, this.validation);

  @override
  String toString() => message;
}

class GeoMath {
  const GeoMath._();

  // ──────────────────────────────────────────────
  // 1. AREA CALCULATION (Equirectangular + Shoelace)
  // ──────────────────────────────────────────────

  static double calculatePolygonAreaSqm(List<LatLng> coords) {
    if (coords.length < 3) return 0;

    double avgLat = 0;
    for (final c in coords) {
      avgLat += c.latitude;
    }
    avgLat /= coords.length;
    final latRad = avgLat * math.pi / 180.0;

    const double metersPerDegreeLat = 111320.0;
    final double metersPerDegreeLng = 111320.0 * math.cos(latRad);

    double sum = 0;
    for (int i = 0; i < coords.length; i++) {
      final j = (i + 1) % coords.length;
      final xi = coords[i].longitude * metersPerDegreeLng;
      final yi = coords[i].latitude * metersPerDegreeLat;
      final xj = coords[j].longitude * metersPerDegreeLng;
      final yj = coords[j].latitude * metersPerDegreeLat;
      sum += (xi * yj) - (xj * yi);
    }

    return sum.abs() / 2.0;
  }

  static double calculateAreaFromCoords(List<List<double>> coords) {
    return calculatePolygonAreaSqm(
      coords.map((c) => LatLng(c[1], c[0])).toList(),
    );
  }

  // ──────────────────────────────────────────────
  // 2. DISTANCE (Haversine)
  // ──────────────────────────────────────────────

  static double haversine(LatLng p1, LatLng p2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((p2.latitude - p1.latitude) * p) / 2 +
        math.cos(p1.latitude * p) *
            math.cos(p2.latitude * p) *
            (1 - math.cos((p2.longitude - p1.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  static double totalRouteDistance(List<LatLng> route) {
    double total = 0;
    for (int i = 1; i < route.length; i++) {
      total += haversine(route[i - 1], route[i]);
    }
    return total;
  }

  // ──────────────────────────────────────────────
  // 3. OVERLAP DETECTION (Ray Casting + Edge Intersection)
  // ──────────────────────────────────────────────

  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Check if two line segments intersect
  static bool _segmentsIntersect(
    LatLng p1, LatLng p2, LatLng p3, LatLng p4,
  ) {
    double d1 = _crossProduct(p3, p4, p1);
    double d2 = _crossProduct(p3, p4, p2);
    double d3 = _crossProduct(p1, p2, p3);
    double d4 = _crossProduct(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static double _crossProduct(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  /// Check if any edges of two polygons intersect
  static bool _edgesIntersect(List<LatLng> polyA, List<LatLng> polyB) {
    for (int i = 0; i < polyA.length; i++) {
      int nextI = (i + 1) % polyA.length;
      for (int j = 0; j < polyB.length; j++) {
        int nextJ = (j + 1) % polyB.length;
        if (_segmentsIntersect(
            polyA[i], polyA[nextI], polyB[j], polyB[nextJ])) {
          return true;
        }
      }
    }
    return false;
  }

  static double estimateOverlapRatio(
      List<LatLng> polyA, List<LatLng> polyB) {
    int insideCount = 0;
    for (final point in polyA) {
      if (isPointInPolygon(point, polyB)) insideCount++;
    }
    final ratioA = polyA.isEmpty ? 0.0 : insideCount / polyA.length;

    insideCount = 0;
    for (final point in polyB) {
      if (isPointInPolygon(point, polyA)) insideCount++;
    }
    final ratioB = polyB.isEmpty ? 0.0 : insideCount / polyB.length;

    return math.max(ratioA, ratioB);
  }

  static OverlapResult checkOverlap(
      List<LatLng> existingPoly, List<LatLng> newPoly) {
    // First check vertex-in-polygon
    final ratio = estimateOverlapRatio(existingPoly, newPoly);
    if (ratio > 0.5) return OverlapResult.stolen;
    if (ratio > 0.1) return OverlapResult.contested;

    // If vertex check shows no overlap, check edge intersections
    // (handles cross-shaped overlaps where no vertices are inside)
    if (ratio == 0 && _edgesIntersect(existingPoly, newPoly)) {
      return OverlapResult.contested;
    }

    return OverlapResult.independent;
  }

  // ──────────────────────────────────────────────
  // 4. CAPTURE VALIDATION
  // ──────────────────────────────────────────────

  static const Map<String, double> speedLimits = {
    'Walk': 3.0,
    'Run': 8.0,
    'Cycle': 15.0,
  };

  static CaptureValidation validateCapture({
    required List<LatLng> route,
    required int durationSeconds,
    required String activityType,
  }) {
    if (route.length < 10) return CaptureValidation.tooFewPoints;
    if (durationSeconds < 60) return CaptureValidation.tooShort;

    final distance = totalRouteDistance(route);
    final speed = distance / (durationSeconds > 0 ? durationSeconds : 1);
    final maxSpeed = speedLimits[activityType] ?? 8.0;
    if (speed > maxSpeed) return CaptureValidation.tooFast;

    final area = calculatePolygonAreaSqm(route);
    if (area < 100) return CaptureValidation.areaTooSmall;
    if (area > 500000) return CaptureValidation.areaTooLarge;

    final closingDist = haversine(route.first, route.last);
    if (distance > 0 && closingDist / distance > 0.8) {
      return CaptureValidation.notALoop;
    }

    for (int i = 1; i < route.length; i++) {
      if (haversine(route[i - 1], route[i]) > 200) {
        return CaptureValidation.teleportDetected;
      }
    }

    return CaptureValidation.valid;
  }

  static String validationMessage(CaptureValidation result) {
    switch (result) {
      case CaptureValidation.valid:
        return 'Valid capture';
      case CaptureValidation.tooFewPoints:
        return 'Not enough GPS data. Move more before capturing.';
      case CaptureValidation.tooShort:
        return 'Run for at least 60 seconds before capturing.';
      case CaptureValidation.areaTooSmall:
        return 'Territory too small. Make a wider loop (min 100 m²).';
      case CaptureValidation.areaTooLarge:
        return 'Territory too large. Max 500K m² per capture.';
      case CaptureValidation.tooFast:
        return 'Moving too fast for this activity.';
      case CaptureValidation.notALoop:
        return 'Route is too linear. Make a loop to form a territory.';
      case CaptureValidation.teleportDetected:
        return 'GPS anomaly detected. Signal may be unstable.';
    }
  }

  // ──────────────────────────────────────────────
  // 5. GPS SIMPLIFICATION (Ramer-Douglas-Peucker)
  // ──────────────────────────────────────────────

  static List<LatLng> simplifyRoute(List<LatLng> points,
      {double epsilon = 0.00005}) {
    if (points.length <= 2) return List.from(points);

    double maxDist = 0;
    int maxIndex = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final dist =
          _perpendicularDistance(points[i], points.first, points.last);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left =
          simplifyRoute(points.sublist(0, maxIndex + 1), epsilon: epsilon);
      final right =
          simplifyRoute(points.sublist(maxIndex), epsilon: epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(
      LatLng point, LatLng lineStart, LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return math.sqrt(
        math.pow(point.longitude - lineStart.longitude, 2) +
            math.pow(point.latitude - lineStart.latitude, 2),
      );
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final clampedT = t.clamp(0.0, 1.0);

    final closestX = lineStart.longitude + clampedT * dx;
    final closestY = lineStart.latitude + clampedT * dy;

    return math.sqrt(
      math.pow(point.longitude - closestX, 2) +
          math.pow(point.latitude - closestY, 2),
    );
  }

  // ──────────────────────────────────────────────
  // 6. PLAYER COLOR GENERATION
  // ──────────────────────────────────────────────

  /// Generate a consistent, muted color from a player name
  static String generatePlayerColor(String name) {
    final hash = name.hashCode;
    final random = math.Random(hash);
    // Reduced saturation (0.65) and lightness (0.55) for less neon, more readable
    final hslColor =
        HSLColor.fromAHSL(1.0, random.nextDouble() * 360, 0.65, 0.55);
    final color = hslColor.toColor();
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase()}';
  }
}
