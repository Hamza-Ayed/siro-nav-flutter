import 'nav_point.dart';
import 'nav_route_details.dart';
import 'nav_step.dart';
import 'speed_camera.dart';

/// Complete navigation route parsed from Siro routing API.
class NavRoute {
  final String id;
  final String routeName;
  final List<NavPoint> polyline;
  final List<NavStep> steps;
  final List<SpeedCamera> speedCameras;
  final double totalDistanceMeters;
  final double totalDurationSeconds;

  /// Traffic, fuel, terrain, speed limits and names, when the API sent them.
  final NavRouteDetails? details;

  const NavRoute({
    required this.id,
    required this.routeName,
    required this.polyline,
    required this.steps,
    this.speedCameras = const [],
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    this.details,
  });

  bool get isEmpty => polyline.isEmpty;
  bool get isNotEmpty => polyline.isNotEmpty;
}
