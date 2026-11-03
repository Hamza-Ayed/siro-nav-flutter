import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Asks for the location access turn-by-turn guidance needs.
///
/// Geolocator asks for "While Using the App" on iOS. Guidance keeps running
/// after the driver switches to another app only with "Always", so this asks
/// for the upgrade as well.
class NavLocationPermission {
  NavLocationPermission._();

  /// Long enough for the driver to read and answer a system prompt.
  static const Duration _promptTimeout = Duration(seconds: 30);

  /// The phone's last known fix when it is recent and accurate enough to start
  /// a route from, so the trip does not wait for a fresh GPS lock.
  static Future<NavPoint?> recentPosition({
    Duration maxAge = const Duration(minutes: 2),
    double maxAccuracyMeters = 100,
  }) async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      if (DateTime.now().difference(p.timestamp) > maxAge) return null;
      if (p.accuracy > maxAccuracyMeters) return null;
      return NavPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        heading: p.heading >= 0 ? p.heading : 0,
        speedKmh: p.speed >= 0 ? p.speed * 3.6 : 0,
        accuracy: p.accuracy,
        timestamp: p.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns true when location can be used at all. Call [hasBackgroundAccess]
  /// afterwards to know whether guidance survives the app going to background.
  static Future<bool> request({bool background = true}) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission()
          .timeout(_promptTimeout, onTimeout: () => LocationPermission.denied);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (background && permission == LocationPermission.whileInUse) {
      // On iOS this shows the "Change to Always" prompt. Android handles
      // background access through its foreground service instead.
      // On iOS this request never completes when the system decides not to
      // show the prompt again, so it must not block the trip.
      await Permission.locationAlways
          .request()
          .timeout(_promptTimeout, onTimeout: () => PermissionStatus.denied);
    }
    return true;
  }

  /// True when the app may read location while in the background.
  /// A check that fails (for example with no platform channel) counts as no,
  /// so the trip continues in the foreground instead of failing.
  static Future<bool> hasBackgroundAccess() async {
    try {
      return await Geolocator.checkPermission() == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// The permission the system currently holds, for diagnostics screens.
  static Future<LocationPermission> currentStatus() =>
      Geolocator.checkPermission();

  /// Opens this app's page in iOS Settings, where "Always" can be chosen.
  /// On iOS the system asks for "Always" only once, so this is the way back.
  static Future<bool> openSettings() => openAppSettings();
}
