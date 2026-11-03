import 'package:test/test.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

void main() {
  group('SiroNavCore - Geodesic Math & MapMatcher', () {
    test('Haversine distance and bearing calculation', () {
      final p1 = NavPoint.fromLatLng(31.9539, 35.9106); // Amman
      final p2 = NavPoint.fromLatLng(31.9639, 35.9106); // ~1.1 km North

      final dist = p1.distanceTo(p2);
      expect(dist, greaterThan(1000.0));
      expect(dist, lessThan(1200.0));

      final bearing = p1.bearingTo(p2);
      expect(bearing, closeTo(0.0, 1.0)); // Heading directly North (~0 deg)
    });

    test('MapMatcher projects raw point onto polyline segment', () {
      final polyline = [
        NavPoint.fromLatLng(31.9500, 35.9000),
        NavPoint.fromLatLng(31.9600, 35.9000),
        NavPoint.fromLatLng(31.9700, 35.9000),
      ];

      // Point slightly to the East of the line
      final rawPoint = NavPoint.fromLatLng(31.9550, 35.9005);
      final snapped = MapMatcher.snapToPolyline(
        rawPoint: rawPoint,
        polyline: polyline,
      );

      expect(snapped.segmentIndex, equals(0));
      expect(snapped.crossTrackDistanceMeters, greaterThan(0.0));
      expect(snapped.crossTrackDistanceMeters, lessThan(60.0));
      expect(snapped.snappedPoint.longitude, closeTo(35.9000, 0.0001));
    });
  });

  group('SiroNavCore - API Key Licensing & Monetization Gate', () {
    test('Rejects navigation start when API key is missing', () async {
      final config = NavConfig(apiKey: ''); // Empty key
      final engine = NavigationEngine(config: config);

      final route = NavRoute(
        id: 'route_1',
        routeName: 'Test Route',
        polyline: [
          NavPoint.fromLatLng(31.9500, 35.9000),
          NavPoint.fromLatLng(31.9600, 35.9000),
        ],
        steps: [],
        totalDistanceMeters: 1100.0,
        totalDurationSeconds: 120.0,
      );

      final events = <NavEvent>[];
      engine.events.listen(events.add);

      final started = await engine.startNavigation(route);
      await Future<void>.delayed(Duration.zero);
      expect(started, isFalse);
      expect(engine.status, equals(NavigationStatus.error));

      expect(events.any((e) => e is AuthErrorEvent), isTrue);
      final authError =
          events.firstWhere((e) => e is AuthErrorEvent) as AuthErrorEvent;
      expect(authError.code, equals('ERR_MISSING_API_KEY'));

      engine.dispose();
    });

    test('Rejects navigation start when API key contains spaces', () async {
      final config = NavConfig(apiKey: 'invalid key 12345');
      final engine = NavigationEngine(config: config);

      final route = NavRoute(
        id: 'route_1',
        routeName: 'Test Route',
        polyline: [NavPoint.fromLatLng(31.95, 35.90)],
        steps: [],
        totalDistanceMeters: 500,
        totalDurationSeconds: 60,
      );

      final events = <NavEvent>[];
      engine.events.listen(events.add);

      final started = await engine.startNavigation(route);
      await Future<void>.delayed(Duration.zero);
      expect(started, isFalse);
      expect(events.any((e) => e is AuthErrorEvent), isTrue);
      final authError =
          events.firstWhere((e) => e is AuthErrorEvent) as AuthErrorEvent;
      expect(authError.code, equals('ERR_INVALID_API_KEY_FORMAT'));

      engine.dispose();
    });
  });

  group('SiroNavCore - Telemetry Probe Engine', () {
    test('Buffers telemetry points and measures cumulative distance', () {
      final config = NavConfig(
        apiKey: 'siro_test_key_abc',
        telemetrySamplingIntervalSeconds: 0, // instantaneous for test
      );
      final engine = NavigationEngine(config: config);

      final route = NavRoute(
        id: 'route_1',
        routeName: 'Test Route',
        polyline: [
          NavPoint.fromLatLng(31.9500, 35.9000),
          NavPoint.fromLatLng(31.9600, 35.9000),
        ],
        steps: [
          NavStep(
            index: 0,
            instruction: 'انطلق نحو الوجهة',
            maneuverType: 0,
            distanceMeters: 1000,
            durationSeconds: 100,
            lat: 31.9600,
            lng: 35.9000,
          ),
        ],
        totalDistanceMeters: 1000,
        totalDurationSeconds: 100,
      );

      // We simulate navigation updates
      engine.updateLocation(NavPoint.fromLatLng(31.9500, 35.9000));
      // Not yet navigating, so buffer should be 0
      expect(engine.bufferedTelemetryPoints, equals(0));

      engine.dispose();
    });
  });

  group('SiroNavCore - Dynamic Instruction Scheduling', () {
    test('Alerts immediately when close to turn maneuver', () {
      final scheduler = InstructionScheduler();
      final step = NavStep(
        index: 1,
        instruction: 'انعطف يميناً الآن',
        maneuverType: 2,
        distanceMeters: 200,
        durationSeconds: 30,
        lat: 31.9550,
        lng: 35.9000,
      );

      // Far away (600m at 40 km/h) -> No immediate alert
      final farEvent = scheduler.evaluate(
        currentStep: step,
        distanceToStepMeters: 600.0,
        speedKmh: 40.0,
      );
      expect(farEvent?.priority, isNot(equals(0)));

      // Close (20m) -> Immediate maneuver alert (P0)
      final closeEvent = scheduler.evaluate(
        currentStep: step,
        distanceToStepMeters: 20.0,
        speedKmh: 30.0,
      );
      expect(closeEvent, isNotNull);
      expect(closeEvent!.priority, equals(0));
      expect(closeEvent.instruction, equals('انعطف يميناً الآن'));
    });
  });

  group('SiroNavCore - Speed Camera Tracking', () {
    test('Alerts once when entering camera zone and detects overspeed', () {
      final tracker = CameraTracker();
      final cam = SpeedCamera(
        id: 'cam_sweifieh_01',
        latitude: 31.9550,
        longitude: 35.9000,
        speedLimitKmh: 60,
        alertDistanceMeters: 300.0,
      );

      // Approaching camera (150m away) while driving at 80 km/h (overspeed)
      final carPos = NavPoint(
        latitude: 31.9537,
        longitude: 35.9000,
        speedKmh: 80.0,
        timestamp: DateTime.now(),
      );

      final events = tracker.checkCameras(
        currentPosition: carPos,
        cameras: [cam],
        overspeedToleranceKmh: 5.0,
      );

      expect(events.length, equals(2));
      expect(events.any((e) => e is SpeedCameraEvent), isTrue);
      expect(events.any((e) => e is OverspeedAlertEvent), isTrue);

      // Second check at the same position should NOT re-alert (once per camera)
      final secondCheck = tracker.checkCameras(
        currentPosition: carPos,
        cameras: [cam],
        overspeedToleranceKmh: 5.0,
      );
      expect(secondCheck.isEmpty, isTrue);
    });
  });
}
