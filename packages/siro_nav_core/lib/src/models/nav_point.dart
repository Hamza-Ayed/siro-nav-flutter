import 'dart:math' as math;

/// Single geographic point representation for navigation and telemetry.
class NavPoint {
  final double latitude;
  final double longitude;
  final double heading; // 0..360 degrees
  final double speedKmh; // speed in km/h
  final double altitude; // meters AMSL
  final double accuracy; // horizontal accuracy in meters
  final DateTime timestamp;

  const NavPoint({
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    this.speedKmh = 0.0,
    this.altitude = 0.0,
    this.accuracy = 5.0,
    required this.timestamp,
  });

  /// Factory constructor for simple coordinate instantiation
  factory NavPoint.fromLatLng(double lat, double lng, {DateTime? time}) {
    return NavPoint(
      latitude: lat,
      longitude: lng,
      timestamp: time ?? DateTime.now(),
    );
  }

  /// Calculates geodesic distance to another point in meters using the Haversine formula.
  double distanceTo(NavPoint other) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(other.latitude - latitude);
    final double dLng = _degToRad(other.longitude - longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(latitude)) *
            math.cos(_degToRad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates forward bearing in degrees (0..360) from this point to another point.
  double bearingTo(NavPoint other) {
    final double lat1 = _degToRad(latitude);
    final double lat2 = _degToRad(other.latitude);
    final double dLng = _degToRad(other.longitude - longitude);

    final double y = math.sin(dLng) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final double initialBearing = math.atan2(y, x);
    return (_radToDeg(initialBearing) + 360.0) % 360.0;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed_kmh': speedKmh,
        'altitude': altitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}
