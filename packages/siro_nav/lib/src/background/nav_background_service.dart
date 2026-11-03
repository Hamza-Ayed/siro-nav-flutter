import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Manages high-precision location updates with background execution resilience.
/// Protects the navigation session from aggressive OEM battery savers on Android and iOS.
class NavBackgroundService {
  StreamSubscription<Position>? _positionSubscription;

  /// Starts streaming GPS positions configured for foreground navigation.
  ///
  /// With [backgroundUpdates] the stream keeps running after the app leaves the
  /// screen. iOS needs "Always" permission for that, so the caller checks it first.
  Stream<NavPoint> startPositionStream({
    String notificationTitle = 'ملاحة سيرو نشطة 🧭',
    String notificationBody = 'استمر في السير نحو وجهتك...',
    bool backgroundUpdates = false,
  }) {
    final controller = StreamController<NavPoint>.broadcast();

    LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Update every 2 meters for smooth navigation
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationBody,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        // The blue bar tells the driver the app is using location in the background.
        showBackgroundLocationIndicator: backgroundUpdates,
        allowBackgroundLocationUpdates: backgroundUpdates,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) {
        controller.add(NavPoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          // -1 = unknown: iOS gives no course or speed at walking pace. The
          // controller then derives them from movement.
          heading: pos.heading >= 0 ? pos.heading : -1.0,
          speedKmh: pos.speed >= 0 ? (pos.speed * 3.6) : -1.0,
          altitude: pos.altitude,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        ));
      },
      onError: (err) {
        controller.addError(err);
      },
    );

    return controller.stream;
  }

  /// Cancels position stream
  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
