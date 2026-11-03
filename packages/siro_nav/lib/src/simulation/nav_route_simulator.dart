import 'dart:async';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Emits [NavPoint]s that drive along a route at a fixed speed.
///
/// Use it where real GPS is not available: the simulator, unit tests, and demos.
/// It is a location source, so the controller feeds it into the same engine
/// path as real GPS.
class NavRouteSimulator {
  final double speedKmh;
  final Duration tick;

  final StreamController<NavPoint> _controller =
      StreamController<NavPoint>.broadcast();
  late NavRoute _route;
  late List<double> _cumulativeMeters;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  double _travelledMeters = 0;

  NavRouteSimulator({
    required NavRoute route,
    this.speedKmh = 60,
    this.tick = const Duration(milliseconds: 500),
  })  : assert(speedKmh > 0),
        assert(
            route.polyline.length >= 2, 'A simulated route needs two points') {
    _setRoute(route);
  }

  /// Positions along the simulated route, one per [tick] while running.
  Stream<NavPoint> get points => _controller.stream;

  bool get isRunning => _timer != null;

  double get travelledMeters => _travelledMeters;

  double get totalMeters => _cumulativeMeters.last;

  /// Emits the start position at once, then one point per [tick].
  ///
  /// Distance is based on the real time between ticks, so a busy UI slows the
  /// tick rate but not the simulated speed.
  void start() {
    stop();
    _travelledMeters = 0;
    _emit();
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(tick, (_) {
      final elapsedSeconds = _clock.elapsedMicroseconds / 1e6;
      _clock
        ..reset()
        ..start();
      _travelledMeters += speedKmh / 3.6 * elapsedSeconds;
      if (_travelledMeters >= totalMeters) {
        _travelledMeters = totalMeters;
        _emit();
        stop();
        return;
      }
      _emit();
    });
  }

  /// Continues from the current position on [route], for example after a reroute.
  void switchRoute(NavRoute route) {
    _setRoute(route);
    _travelledMeters = 0;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void dispose() {
    stop();
    _controller.close();
  }

  /// Position after travelling [meters] along the route.
  NavPoint pointAt(double meters) {
    final target = meters.clamp(0.0, totalMeters);
    var segment = 0;
    while (segment < _cumulativeMeters.length - 2 &&
        _cumulativeMeters[segment + 1] < target) {
      segment++;
    }

    final from = _route.polyline[segment];
    final to = _route.polyline[segment + 1];
    final segmentLength =
        _cumulativeMeters[segment + 1] - _cumulativeMeters[segment];
    final t = segmentLength == 0
        ? 0.0
        : (target - _cumulativeMeters[segment]) / segmentLength;

    return NavPoint(
      latitude: from.latitude + (to.latitude - from.latitude) * t,
      longitude: from.longitude + (to.longitude - from.longitude) * t,
      heading: from.bearingTo(to),
      speedKmh: speedKmh,
      accuracy: 5.0,
      timestamp: DateTime.now(),
    );
  }

  void _setRoute(NavRoute route) {
    assert(route.polyline.length >= 2, 'A simulated route needs two points');
    _route = route;
    _cumulativeMeters = [0.0];
    for (var i = 1; i < route.polyline.length; i++) {
      _cumulativeMeters.add(
        _cumulativeMeters.last +
            route.polyline[i - 1].distanceTo(route.polyline[i]),
      );
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(pointAt(_travelledMeters));
    }
  }
}
