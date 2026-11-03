import '../models/nav_point.dart';
import '../models/speed_camera.dart';
import '../events/nav_events.dart';

/// Monitors speed cameras and traffic enforcement points ahead of the vehicle.
class CameraTracker {
  final Set<String> _announcedCameraIds = {};

  void reset() {
    _announcedCameraIds.clear();
  }

  /// Checks for any approaching speed camera within alert distance.
  List<NavEvent> checkCameras({
    required NavPoint currentPosition,
    required List<SpeedCamera> cameras,
    required double overspeedToleranceKmh,
  }) {
    final List<NavEvent> events = [];

    for (final cam in cameras) {
      if (_announcedCameraIds.contains(cam.id)) continue;

      final dist = currentPosition.distanceTo(cam.position);
      if (dist <= cam.alertDistanceMeters) {
        _announcedCameraIds.add(cam.id);
        events.add(SpeedCameraEvent(
          camera: cam,
          distanceMeters: dist,
        ));

        // Check if vehicle is overspeeding approaching the camera
        // A camera without a known limit (0) can only warn, never flag overspeed.
        if (cam.speedLimitKmh > 0 &&
            currentPosition.speedKmh >
                (cam.speedLimitKmh + overspeedToleranceKmh)) {
          events.add(OverspeedAlertEvent(
            currentSpeedKmh: currentPosition.speedKmh,
            speedLimitKmh: cam.speedLimitKmh,
          ));
        }
      }
    }

    return events;
  }
}
