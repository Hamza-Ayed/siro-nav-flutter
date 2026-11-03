/// Telemetry point snapshot recorded during active navigation or tracking.
/// Fully compatible with Siro MapSaaS backend /telemetry and /telemetry/batch endpoints.
class TelemetryPoint {
  final String driverId;
  final double latitude;
  final double longitude;
  final double speed; // km/h
  final double heading; // 0..360 degrees
  final double elevation; // meters AMSL
  final double distance; // cumulative trip distance in meters
  final DateTime timestamp;

  const TelemetryPoint({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    this.elevation = 0.0,
    this.distance = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed < 0 ? 0.0 : speed,
        'heading': heading < 0 ? 0.0 : heading,
        'elevation': elevation,
        'distance': distance,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) {
    return TelemetryPoint(
      driverId: json['driver_id'] as String? ?? 'anonymous_driver',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
