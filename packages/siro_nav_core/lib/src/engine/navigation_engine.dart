import 'dart:async';
import '../models/nav_config.dart';
import '../models/nav_point.dart';
import '../models/nav_route.dart';
import '../models/nav_step.dart';
import '../events/nav_events.dart';
import '../auth/api_key_validator.dart';
import '../telemetry/telemetry_collector.dart';
import 'map_matcher.dart';
import 'instruction_scheduler.dart';
import 'camera_tracker.dart';

enum NavigationStatus {
  idle,
  authenticating,
  navigating,
  rerouting,
  arrived,
  error,
}

/// Headless Turn-by-Turn Navigation Engine (Pure Dart).
/// Coordinates route matching, instruction timing, rerouting, speed enforcement,
/// and live telemetry probe streaming.
class NavigationEngine {
  final NavConfig config;
  final StreamController<NavEvent> _eventController =
      StreamController<NavEvent>.broadcast();

  late final ApiKeyValidator _authValidator;
  late final TelemetryCollector _telemetryCollector;
  final InstructionScheduler _instructionScheduler = InstructionScheduler();
  final CameraTracker _cameraTracker = CameraTracker();

  NavigationStatus _status = NavigationStatus.idle;
  NavRoute? _activeRoute;
  int _currentStepIndex = 0;
  int _lastKnownSegmentIndex = 0;
  DateTime? _offRouteStartTime;
  bool _isRerouting = false;
  NavPoint? _displayPoint;

  NavigationEngine({required this.config}) {
    _authValidator = ApiKeyValidator(config: config);
    _telemetryCollector = TelemetryCollector(
      config: config,
      eventController: _eventController,
    );
  }

  /// Broadcast stream of all navigation, instruction, progress, telemetry, and error events.
  Stream<NavEvent> get events => _eventController.stream;

  NavigationStatus get status => _status;

  /// Where the vehicle should be drawn right now: the road-snapped point on the
  /// route, or the raw fix while the driver is off it. Updated synchronously in
  /// [updateLocation], so UI code can read it straight after a location update.
  NavPoint? get displayPoint => _displayPoint;
  NavRoute? get activeRoute => _activeRoute;
  int get currentStepIndex => _currentStepIndex;
  int get bufferedTelemetryPoints => _telemetryCollector.bufferedCount;
  double get cumulativeDistanceMeters =>
      _telemetryCollector.cumulativeDistanceMeters;

  /// Starts an active navigation session along [route].
  /// Enforces API Key subscription validation before commencing guidance.
  Future<bool> startNavigation(NavRoute route) async {
    _status = NavigationStatus.authenticating;

    // 1. Mandatory Monetization & Licensing Gate
    final authResult = await _authValidator.validate();
    if (!authResult.isValid) {
      _status = NavigationStatus.error;
      _eventController.add(AuthErrorEvent(
        code: authResult.errorCode ?? 'ERR_AUTH_DENIED',
        message: authResult.errorMessage ?? 'API Key validation failed',
      ));
      return false;
    }

    if (route.isEmpty) {
      _status = NavigationStatus.error;
      return false;
    }

    _activeRoute = route;
    _displayPoint = null;
    _currentStepIndex = 0;
    _lastKnownSegmentIndex = 0;
    _offRouteStartTime = null;
    _isRerouting = false;
    _instructionScheduler.reset();
    _cameraTracker.reset();

    // 2. Start Telemetry probe engine
    _telemetryCollector.start();

    _status = NavigationStatus.navigating;

    // Emit initial instruction if available
    if (route.steps.isNotEmpty) {
      final firstStep = route.steps.first;
      _eventController.add(InstructionEvent(
        stepIndex: 0,
        instruction: firstStep.instruction,
        streetName: firstStep.streetName,
        maneuverType: firstStep.maneuverType,
        exitNumber: firstStep.exitNumber,
        distanceMeters: firstStep.distanceMeters,
        timeSeconds: firstStep.durationSeconds.round(),
        priority: 2,
        ttlSeconds: 30,
      ));
    }

    return true;
  }

  /// Core location update handler. Ingests raw GPS tick and processes map matching,
  /// instruction scheduling, speed cameras, off-route deviations, and telemetry.
  void updateLocation(NavPoint rawPoint) {
    if (_status != NavigationStatus.navigating || _activeRoute == null) return;

    // 1. Ingest into Telemetry probe buffer for live fleet tracking
    _telemetryCollector.recordPoint(rawPoint);

    // 2. Check GPS accuracy degradation
    if (rawPoint.accuracy > 40.0) {
      _eventController.add(GpsSignalDegradedEvent(
        currentAccuracyMeters: rawPoint.accuracy,
      ));
    }

    // 3. Map Matching: Snap raw GPS onto active route polyline
    final snapped = MapMatcher.snapToPolyline(
      rawPoint: rawPoint,
      polyline: _activeRoute!.polyline,
      lastKnownSegmentIndex: _lastKnownSegmentIndex,
    );
    _lastKnownSegmentIndex = snapped.segmentIndex;

    // 4. Off-Route Deviation Detection
    final double dynamicOffRouteThreshold =
        config.offRouteThresholdMeters + (rawPoint.accuracy > 15 ? 10.0 : 0.0);

    if (snapped.crossTrackDistanceMeters > dynamicOffRouteThreshold) {
      _displayPoint = rawPoint;
      _handleOffRoute(rawPoint, snapped.crossTrackDistanceMeters);
      return;
    } else {
      // Re-snapped within acceptable bounds
      _offRouteStartTime = null;
      // Snap to the road only when actually on it. Near the route but off the
      // road (a house, a car park) the driver sees the real position.
      _displayPoint =
          snapped.crossTrackDistanceMeters <= config.snapToRouteMeters
              ? snapped.snappedPoint
              : rawPoint;
    }

    // 5. Update Step Progression
    _updateStepProgression(snapped.snappedPoint);

    // 6. Check Arrival Condition (within 20m of final coordinate)
    final destination = _activeRoute!.polyline.last;
    final distToDest = snapped.snappedPoint.distanceTo(destination);
    if (distToDest <= 20.0) {
      _status = NavigationStatus.arrived;
      _eventController.add(ArrivalEvent(
        finalPosition: snapped.snappedPoint,
        totalDistanceTraveledMeters:
            _telemetryCollector.cumulativeDistanceMeters,
        totalDurationSeconds: 0,
      ));
      stopNavigation();
      return;
    }

    // 7. Calculate Remaining Metrics & Progress
    final double remainingDistance =
        (_activeRoute!.totalDistanceMeters - snapped.distanceAlongRouteMeters)
            .clamp(0.0, double.infinity);
    final double fraction = _activeRoute!.totalDistanceMeters > 0
        ? (snapped.distanceAlongRouteMeters / _activeRoute!.totalDistanceMeters)
            .clamp(0.0, 1.0)
        : 1.0;

    // A route without steps still gets progress, just no maneuver distance.
    final steps = _activeRoute!.steps;
    final NavStep? currentStep = steps.isEmpty
        ? null
        : (_currentStepIndex < steps.length
            ? steps[_currentStepIndex]
            : steps.last);
    final double distToManeuver = currentStep == null
        ? remainingDistance
        : snapped.snappedPoint
            .distanceTo(NavPoint.fromLatLng(currentStep.lat, currentStep.lng));

    _eventController.add(ProgressEvent(
      rawPosition: rawPoint,
      snappedPosition: snapped.snappedPoint,
      distanceToNextManeuverMeters: distToManeuver,
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds:
          (remainingDistance / 11.0).round(), // ~40 km/h baseline
      currentSpeedKmh: rawPoint.speedKmh,
      currentStepIndex: _currentStepIndex,
      progressFraction: fraction,
    ));

    // 8. Dynamic Speed-Based Instruction Scheduling
    final instructionEvent = currentStep == null
        ? null
        : _instructionScheduler.evaluate(
            currentStep: currentStep,
            distanceToStepMeters: distToManeuver,
            speedKmh: rawPoint.speedKmh,
          );
    if (instructionEvent != null) {
      _eventController.add(instructionEvent);
    }

    // 9. Speed Cameras & Speed Limit Enforcement
    final cameraEvents = _cameraTracker.checkCameras(
      currentPosition: rawPoint,
      cameras: _activeRoute!.speedCameras,
      overspeedToleranceKmh: config.overspeedToleranceKmh,
    );
    for (final camEv in cameraEvents) {
      _eventController.add(camEv);
    }
  }

  void _handleOffRoute(NavPoint rawPoint, double deviationMeters) {
    final now = DateTime.now();
    _offRouteStartTime ??= now;

    final elapsed = now.difference(_offRouteStartTime!).inSeconds;
    _eventController.add(OffRouteEvent(
      currentPosition: rawPoint,
      deviationMeters: deviationMeters,
      offRouteDurationSeconds: elapsed,
    ));

    if (elapsed >= config.offRouteDebounceSeconds && !_isRerouting) {
      _isRerouting = true;
      _status = NavigationStatus.rerouting;
      _eventController.add(RerouteTriggeredEvent(
        deviationPoint: rawPoint,
        reason: 'continuous_deviation_detected',
      ));
    }
  }

  void _updateStepProgression(NavPoint snappedPoint) {
    if (_activeRoute == null || _activeRoute!.steps.isEmpty) return;

    while (_currentStepIndex < _activeRoute!.steps.length - 1) {
      final currentStep = _activeRoute!.steps[_currentStepIndex];
      final target = NavPoint.fromLatLng(currentStep.lat, currentStep.lng);
      final dist = snappedPoint.distanceTo(target);

      // Passed maneuver within 25 meters
      if (dist < 25.0) {
        _currentStepIndex++;
        final nextStep = _activeRoute!.steps[_currentStepIndex];
        _eventController.add(InstructionEvent(
          stepIndex: _currentStepIndex,
          instruction: nextStep.instruction,
          streetName: nextStep.streetName,
          maneuverType: nextStep.maneuverType,
          exitNumber: nextStep.exitNumber,
          distanceMeters: nextStep.distanceMeters,
          timeSeconds: nextStep.durationSeconds.round(),
          priority: 2,
        ));
      } else {
        break;
      }
    }
  }

  /// Replaces the active route after a successful reroute from server.
  void updateRouteAfterReroute(NavRoute newRoute) {
    _activeRoute = newRoute;
    _currentStepIndex = 0;
    _lastKnownSegmentIndex = 0;
    _offRouteStartTime = null;
    _isRerouting = false;
    _status = NavigationStatus.navigating;
    _instructionScheduler.reset();
    _eventController.add(RerouteSuccessEvent(newRoute: newRoute));
  }

  /// Stops navigation and flushes final telemetry buffer.
  Future<void> stopNavigation() async {
    _status = NavigationStatus.idle;
    _displayPoint = null;
    await _telemetryCollector.stop();
  }

  void dispose() {
    _status = NavigationStatus.idle;
    _telemetryCollector.dispose();
    _authValidator.dispose();
    _eventController.close();
  }
}
