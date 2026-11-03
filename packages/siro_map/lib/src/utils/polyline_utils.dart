// وظيفة الملف: تنفيذ أو إعداد polyline utils ضمن هذا الجزء من المشروع.
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Utility functions for working with encoded polylines and coordinates.
class PolylineUtils {
  PolylineUtils._();

  // ── Encoding / Decoding ────────────────────────────────────

  /// Decodes a [Google-encoded polyline](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
  /// string into a list of [LatLng] coordinates.
  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Encodes a list of [LatLng] points to a Google-encoded polyline string.
  static String encode(List<LatLng> points) {
    final result = StringBuffer();
    int prevLat = 0, prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1E5).round();
      final lng = (point.longitude * 1E5).round();
      _encodeValue(result, lat - prevLat);
      _encodeValue(result, lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return result.toString();
  }

  static void _encodeValue(StringBuffer buf, int value) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      buf.writeCharCode(((0x20 | (v & 0x1f)) + 63));
      v >>= 5;
    }
    buf.writeCharCode((v + 63));
  }

  // ── Distance ───────────────────────────────────────────────

  /// Returns the Haversine distance in **metres** between two [LatLng] points.
  static double distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0; // metres
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLng * sinDLng;
    return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Returns the total length of a polyline in metres.
  static double totalLength(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  static double _toRad(double deg) => deg * pi / 180.0;
}
