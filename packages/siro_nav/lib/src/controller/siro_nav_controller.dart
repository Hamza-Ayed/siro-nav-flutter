import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:siro_nav_core/siro_nav_core.dart';
import '../billing/nav_trip_meter.dart';
import 'nav_trip_summary.dart';
import '../diagnostics/nav_diagnostics.dart';
import '../permissions/nav_location_permission.dart';
import '../services/routing_client.dart';
import '../background/nav_background_service.dart';
import '../simulation/nav_route_simulator.dart';
import '../voice/nav_voice_catalog.dart';
import '../voice/nav_voice_engine.dart';

/// Turn-by-turn navigation session for one trip, for a Flutter app.
///
/// Fetches the route from Siro Maps, feeds GPS (or a simulated track) into the
/// engine, speaks the guidance, and exposes reactive state for the UI.
///
/// Typical use:
/// ```dart
/// final nav = await SiroNavController.create(config: NavConfig(apiKey: key));
/// await nav.startNavigation(destination: to); // origin = the phone's location
/// // Show SiroNavView(controller: nav) and handle nav.isNavigating.
/// ```
class SiroNavController {
  final NavConfig config;
  late final NavigationEngine _engine;
  late final RoutingClient _routingClient;
  final NavBackgroundService _backgroundService = NavBackgroundService();
  final Stream<NavPoint> Function(bool backgroundUpdates)? _positionSource;
  final Duration _firstFixTimeout;
  final Future<NavPoint?> Function()? _lastKnownPosition;
  NavVoiceEngine? _voiceEngine;
  NavRouteSimulator? _simulator;

  StreamSubscription<NavPoint>? _locationSubscription;
  StreamSubscription<NavEvent>? _eventsSubscription;
  Completer<NavPoint>? _firstFix;

  NavPoint? _destination;
  bool _backgroundGps = false;
  NavTripMeter? _meter;

  /// The last fix that moved at least [_minMoveForHeadingMeters], used to
  /// derive heading and speed when the GPS gives none.
  NavPoint? _motionAnchor;
  static const double _minMoveForHeadingMeters = 3;

  /// The latest raw GPS fix, on or off the route. Use it to show GPS is alive.
  final ValueNotifier<NavPoint?> lastGpsFix = ValueNotifier<NavPoint?>(null);

  /// Where the vehicle is drawn: on the route, or the raw fix when off it.
  final ValueNotifier<NavPoint?> vehiclePosition =
      ValueNotifier<NavPoint?>(null);

  /// True while the route is being recalculated after the driver left it.
  final ValueNotifier<bool> isRerouting = ValueNotifier<bool>(false);

  /// Distance, waiting time and fare for the trip. Null unless a [NavFareConfig] was given.
  final ValueNotifier<NavTripTotals?> tripTotals =
      ValueNotifier<NavTripTotals?>(null);

  /// The leg of the current trip: to the rider, or the ride itself.
  final ValueNotifier<NavTripPhase> phase =
      ValueNotifier<NavTripPhase>(NavTripPhase.trip);

  /// The last finished trip, kept after it ends, for billing or logging.
  final ValueNotifier<NavTripSummary?> lastTrip =
      ValueNotifier<NavTripSummary?>(null);

  DateTime? _tripStartedAt;
  bool _arrived = false;

  /// Mirrors the voice engine's mute state, so buttons can show it.
  final ValueNotifier<bool> voiceMuted = ValueNotifier<bool>(false);

  // Reactive state notifiers for Flutter UI
  final ValueNotifier<bool> isNavigating = ValueNotifier<bool>(false);
  final ValueNotifier<NavRoute?> route = ValueNotifier<NavRoute?>(null);
  final ValueNotifier<InstructionEvent?> currentInstruction =
      ValueNotifier<InstructionEvent?>(null);
  final ValueNotifier<ProgressEvent?> currentProgress =
      ValueNotifier<ProgressEvent?>(null);
  final ValueNotifier<SpeedCameraEvent?> upcomingCamera =
      ValueNotifier<SpeedCameraEvent?>(null);
  final ValueNotifier<double> currentSpeedKmh = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isOverspeeding = ValueNotifier<bool>(false);
  final ValueNotifier<String?> activeError = ValueNotifier<String?>(null);

  /// [routingClient] and [positionSource] are for tests and custom stacks. By
  /// default the controller uses the Siro Maps API and the device GPS.
  SiroNavController({
    required this.config,
    NavVoiceEngine? voiceEngine,
    RoutingClient? routingClient,
    Stream<NavPoint> Function(bool backgroundUpdates)? positionSource,
    Duration firstFixTimeout = const Duration(seconds: 20),
    Future<NavPoint?> Function()? lastKnownPosition,
  })  : _positionSource = positionSource,
        _lastKnownPosition = lastKnownPosition,
        _firstFixTimeout = firstFixTimeout {
    _engine = NavigationEngine(config: config);
    _routingClient = routingClient ?? RoutingClient(config: config);
    _voiceEngine = voiceEngine;
    _bindEngineEvents();
  }

  /// Creates a controller with the bundled Arabic voice prompts.
  static Future<SiroNavController> create({required NavConfig config}) async {
    final catalog = await NavVoiceCatalog.loadFromAsset();
    return SiroNavController(
      config: config,
      voiceEngine: NavVoiceEngine(catalog: catalog),
    );
  }

  /// Attach or replace voice engine dynamically
  void setVoiceEngine(NavVoiceEngine engine) {
    _voiceEngine = engine;
  }

  NavVoiceEngine? get voiceEngine => _voiceEngine;

  bool get isVoiceMuted => _voiceEngine?.isMuted ?? false;

  /// True when the current trip keeps reading GPS while the app is in the background.
  bool get isBackgroundGps => _backgroundGps;

  void setVoiceMuted(bool muted) {
    final engine = _voiceEngine;
    if (engine != null && engine.isMuted != muted) {
      engine.toggleMute();
    }
    voiceMuted.value = isVoiceMuted;
  }

  /// Direct access to the underlying NavEvent stream (for custom integrations).
  Stream<NavEvent> get events => _engine.events;

  NavRoute? get activeRoute => route.value;

  NavigationEngine get engine => _engine;

  void _bindEngineEvents() {
    _eventsSubscription = _engine.events.listen((event) {
      // Forward event to voice engine for speech announcement
      _voiceEngine?.handleNavEvent(event);

      if (event is InstructionEvent) {
        currentInstruction.value = event;
      } else if (event is ProgressEvent) {
        currentProgress.value = event;
        currentSpeedKmh.value = event.currentSpeedKmh;
      } else if (event is SpeedCameraEvent) {
        upcomingCamera.value = event;
      } else if (event is OverspeedAlertEvent) {
        isOverspeeding.value = true;
      } else if (event is RerouteTriggeredEvent) {
        isRerouting.value = true;
        _handleDynamicReroute(event.deviationPoint);
      } else if (event is ArrivalEvent) {
        _arrived = true;
        stopNavigation();
      } else if (event is TelemetryBatchEvent) {
        NavDiagnostics.log('telemetry batch=${event.batchCount} '
            'uploaded=${event.uploaded} pending=${event.pendingBufferedCount}'
            '${event.errorMessage == null ? '' : ' error=${event.errorMessage}'}');
      } else if (event is AuthErrorEvent) {
        activeError.value = '${event.code}: ${event.message}';
        stopNavigation();
      }
    });
  }

  /// Fetches the route and starts guidance.
  ///
  /// [origin] is where the trip starts. In GPS mode leave it null: the trip
  /// starts from the phone's current location, and the GPS listener starts
  /// before the route request, so the first fix is ready when the route is.
  ///
  /// With [simulate] true, the vehicle drives along the returned route at
  /// [simulationSpeedKmh] instead of using GPS, and [origin] is required.
  ///
  /// Returns false and sets [activeError] when the trip cannot start.
  Future<bool> startNavigation({
    NavPoint? origin,
    required NavPoint destination,
    List<NavPoint> waypoints = const [],
    bool simulate = false,
    double simulationSpeedKmh = 60,
    NavFareConfig? fare,
    NavTripPhase phase = NavTripPhase.trip,
  }) async {
    await stopNavigation();
    this.phase.value = phase;
    activeError.value = null;
    _destination = destination;
    _meter = fare == null ? null : NavTripMeter(fare);

    if (simulate && origin == null) {
      activeError.value = 'وضع المحاكاة يحتاج نقطة بداية.';
      return false;
    }

    try {
      final background =
          !simulate && await NavLocationPermission.hasBackgroundAccess();
      _backgroundGps = background;
      NavDiagnostics.log(
          'start simulate=$simulate background=$background origin=${origin != null}');

      var start = origin;
      if (!simulate && start == null) {
        _startGps(background);
        // A recent known location starts the route at once; otherwise wait
        // for the first fix of the stream that is already running.
        final lastKnown = _lastKnownPosition;
        final known = lastKnown != null
            ? await lastKnown()
            : await NavLocationPermission.recentPosition();
        NavDiagnostics.log(
            'last known position ${known == null ? 'none' : 'used'}');
        start = known ?? await _waitForFirstFix();
        if (start == null) {
          activeError.value =
              'ما وصلت إشارة GPS. تأكد إن الموقع مفعّل، وإنك بمكان مفتوح.';
          await stopNavigation();
          return false;
        }
      }

      final fetched = await _routingClient.getRoute(
        origin: start!,
        destination: destination,
        waypoints: waypoints,
      );

      final started = await _engine.startNavigation(fetched);
      if (!started) {
        activeError.value ??= 'تعذر بدء الملاحة.';
        await stopNavigation();
        return false;
      }

      route.value = fetched;
      isNavigating.value = true;
      _tripStartedAt = DateTime.now();
      _arrived = false;
      // Show the meter at zero from the start, not only after the first fix.
      tripTotals.value = _meter?.totals;
      vehiclePosition.value = start;

      if (simulate) {
        _startSimulator(fetched, simulationSpeedKmh);
      } else if (_locationSubscription == null) {
        _startGps(background);
      }
      return true;
    } on NavRouteException catch (e) {
      activeError.value = e.message;
      await stopNavigation();
      return false;
    } catch (e) {
      activeError.value = 'تعذر بدء الملاحة: $e';
      await stopNavigation();
      return false;
    }
  }

  /// Subscribes to GPS. Each fix goes to [_onLocation]. The first fix also
  /// completes [_firstFix], so the trip can start from it.
  void _startGps(bool backgroundUpdates) {
    _locationSubscription?.cancel();
    _simulator?.dispose();
    _simulator = null;
    _firstFix = Completer<NavPoint>();

    final source = _positionSource ??
        (bool background) => _backgroundService.startPositionStream(
            backgroundUpdates: background);

    _locationSubscription = source(backgroundUpdates).listen(
      (point) {
        final first = _firstFix;
        if (first != null && !first.isCompleted) first.complete(point);
        _onLocation(point);
      },
      onError: (Object err) => activeError.value = 'GPS Stream Error: $err',
    );
  }

  /// The first GPS fix of this trip, or null when none arrives in time.
  Future<NavPoint?> _waitForFirstFix() async {
    final first = _firstFix;
    if (first == null) return null;
    try {
      return await first.future.timeout(_firstFixTimeout);
    } on TimeoutException {
      return null;
    }
  }

  void _startSimulator(NavRoute navRoute, double speedKmh) {
    _locationSubscription?.cancel();
    _simulator?.dispose();
    final simulator = NavRouteSimulator(route: navRoute, speedKmh: speedKmh);
    _simulator = simulator;
    _locationSubscription = simulator.points.listen(_onLocation);
    simulator.start();
  }

  /// One place for every location source: the engine, the meter, and the UI.
  void _onLocation(NavPoint raw) {
    final point = _withMotion(raw);
    NavDiagnostics.log(
        'fix ${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)} '
        'acc=${point.accuracy.round()} speed=${point.speedKmh.toStringAsFixed(1)} '
        'heading=${point.heading.round()} status=${_engine.status.name}');
    _engine.updateLocation(point);
    lastGpsFix.value = point;
    vehiclePosition.value = _engine.displayPoint ?? point;
    final meter = _meter;
    if (meter != null) tripTotals.value = meter.addFix(point);
  }

  /// Fills in heading and speed when the GPS reports them as unknown (-1).
  ///
  /// iOS gives no course at walking speed and often in slow traffic. Without
  /// this the arrow and the camera would stay pointed north.
  NavPoint _withMotion(NavPoint p) {
    final anchor = _motionAnchor;
    var heading = p.heading;
    var speed = p.speedKmh;
    var moved = 0.0;
    if (anchor != null) {
      moved = anchor.distanceTo(p);
      final seconds =
          p.timestamp.difference(anchor.timestamp).inMilliseconds / 1000;
      if (heading < 0 && moved >= _minMoveForHeadingMeters) {
        heading = anchor.bearingTo(p);
      }
      if (speed < 0 && seconds > 0 && seconds <= 30) {
        speed = moved / seconds * 3.6;
      }
    }
    if (heading < 0) heading = anchor?.heading ?? 0;
    if (speed < 0) speed = 0;

    final fixed = NavPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      heading: heading,
      speedKmh: speed,
      altitude: p.altitude,
      accuracy: p.accuracy,
      timestamp: p.timestamp,
    );
    if (anchor == null || moved >= _minMoveForHeadingMeters) {
      _motionAnchor = fixed;
    }
    return fixed;
  }

  /// Handles automatic rerouting when driver deviates from the path.
  Future<void> _handleDynamicReroute(NavPoint deviationPoint) async {
    final destination = _destination;
    if (destination == null) {
      isRerouting.value = false;
      return;
    }
    try {
      final newRoute = await _routingClient.getRoute(
        origin: deviationPoint,
        destination: destination,
      );
      route.value = newRoute;
      _simulator?.switchRoute(newRoute);
      _engine.updateRouteAfterReroute(newRoute);
    } catch (e) {
      // On network failure during reroute, engine will retry on next deviation tick
    } finally {
      isRerouting.value = false;
    }
  }

  /// Stops guidance, the location source, and flushes telemetry.
  Future<void> stopNavigation() async {
    // Keep what the trip measured before the state is cleared.
    final startedAt = _tripStartedAt;
    if (isNavigating.value && startedAt != null) {
      lastTrip.value = NavTripSummary(
        phase: phase.value,
        startedAt: startedAt,
        endedAt: DateTime.now(),
        arrived: _arrived,
        totals: tripTotals.value,
      );
    }
    _tripStartedAt = null;

    // Reset the UI state first, so no notifier is written after dispose.
    isNavigating.value = false;
    route.value = null;
    currentInstruction.value = null;
    currentProgress.value = null;
    upcomingCamera.value = null;
    isOverspeeding.value = false;
    isRerouting.value = false;
    vehiclePosition.value = null;
    tripTotals.value = null;
    _meter = null;

    _backgroundGps = false;
    lastGpsFix.value = null;
    _firstFix = null;
    _motionAnchor = null;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _simulator?.dispose();
    _simulator = null;
    _backgroundService.stop();
    await _engine.stopNavigation();
  }

  Future<void> dispose() async {
    await stopNavigation();
    await _eventsSubscription?.cancel();
    _voiceEngine?.dispose();
    _engine.dispose();
    _routingClient.dispose();
    isNavigating.dispose();
    route.dispose();
    currentInstruction.dispose();
    currentProgress.dispose();
    upcomingCamera.dispose();
    currentSpeedKmh.dispose();
    isOverspeeding.dispose();
    activeError.dispose();
    lastGpsFix.dispose();
    vehiclePosition.dispose();
    isRerouting.dispose();
    tripTotals.dispose();
    voiceMuted.dispose();
    phase.dispose();
    lastTrip.dispose();
  }
}
