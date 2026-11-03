import 'dart:math' as math;
import '../models/nav_point.dart';

/// Decodes Google-style encoded polylines.
///
/// Siro Maps returns the route geometry in the `points` field of
/// `/api/maps/route` using this format (precision 5, latitude first).
class PolylineCodec {
  PolylineCodec._();

  /// Throws [FormatException] when [encoded] is truncated or malformed.
  static List<NavPoint> decode(String encoded, {int precision = 5}) {
    final factor = math.pow(10, precision).toDouble();
    final points = <NavPoint>[];
    final now = DateTime.now();
    var index = 0;

    int readDelta() {
      var result = 0;
      var shift = 0;
      int chunk;
      do {
        if (index >= encoded.length) {
          throw const FormatException('Truncated encoded polyline');
        }
        chunk = encoded.codeUnitAt(index++) - 63;
        result |= (chunk & 0x1f) << shift;
        shift += 5;
      } while (chunk >= 0x20);
      return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    }

    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      lat += readDelta();
      lng += readDelta();
      points.add(NavPoint(
        latitude: lat / factor,
        longitude: lng / factor,
        heading: 0.0,
        speedKmh: 0.0,
        altitude: 0.0,
        accuracy: 0.0,
        timestamp: now,
      ));
    }
    return points;
  }
}
