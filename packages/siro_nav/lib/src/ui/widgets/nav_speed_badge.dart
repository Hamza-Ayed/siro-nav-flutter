import 'package:flutter/material.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Speedometer HUD with speed limit circle and radar camera proximity alert.
class NavSpeedBadge extends StatelessWidget {
  final double currentSpeedKmh;
  final SpeedCameraEvent? upcomingCamera;
  final bool isOverspeeding;

  const NavSpeedBadge({
    super.key,
    required this.currentSpeedKmh,
    this.upcomingCamera,
    this.isOverspeeding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera Warning Pill if detected
        if (upcomingCamera != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444), // Red alert
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _cameraLabel(upcomingCamera!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Current Speed Meter
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isOverspeeding
                ? const Color(0xFFEF4444)
                : const Color(0xFF1E293B).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isOverspeeding ? Colors.white : const Color(0xFF38BDF8),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentSpeedKmh.round().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'كم/س',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A limit of 0 means the route data has no speed limit for this camera.
  static String _cameraLabel(SpeedCameraEvent event) {
    final meters = event.distanceMeters.round();
    final limit = event.camera.speedLimitKmh;
    return limit > 0
        ? 'كاميرا $limit كم/س ($metersم)'
        : 'كاميرا أمامك ($metersم)';
  }
}
