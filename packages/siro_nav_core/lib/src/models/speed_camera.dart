import 'nav_point.dart';

/// Speed camera or traffic enforcement point along the route.
class SpeedCamera {
  final String id;
  final double latitude;
  final double longitude;
  final int speedLimitKmh;
  final String type; // 'fixed', 'radar', 'traffic_light'
  final double alertDistanceMeters;

  const SpeedCamera({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.speedLimitKmh,
    this.type = 'fixed',
    this.alertDistanceMeters = 300.0,
  });

  factory SpeedCamera.fromJson(Map<String, dynamic> json) {
    return SpeedCamera(
      id: json['id']?.toString() ?? 'cam_${json['lat']}_${json['lng']}',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      speedLimitKmh: (json['speed_limit'] as num?)?.toInt() ?? 80,
      type: json['type']?.toString() ?? 'fixed',
      alertDistanceMeters:
          (json['alert_distance'] as num?)?.toDouble() ?? 300.0,
    );
  }

  NavPoint get position => NavPoint.fromLatLng(latitude, longitude);
}
