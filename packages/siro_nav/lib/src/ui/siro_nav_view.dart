import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:siro_map/siro_map.dart';
import 'package:siro_nav_core/siro_nav_core.dart';
import '../billing/nav_trip_meter.dart';
import '../controller/siro_nav_controller.dart';
import '../diagnostics/nav_diagnostics.dart';
import 'nav_style_icons.dart';
import 'nav_vehicle_icon.dart';
import 'widgets/nav_instruction_banner.dart';
import 'widgets/nav_bottom_bar.dart';
import 'widgets/nav_speed_badge.dart';

/// Default map style: Siro Limestone, day. Pass a versioned URL (`?v=`) to
/// bypass the CDN cache after a style release.
const String kSiroNavDefaultStyleUrl = 'https://map.intaleqapp.com/style.json';

const String _vehicleImageId = 'siro_nav_vehicle';

/// How far the camera centre may drift from the vehicle before the driver is
/// treated as having moved the map.
const double _dragDetectMeters = 30;

/// Full-screen turn-by-turn view: the Siro map, the route, the moving vehicle,
/// a follow camera, and the guidance HUD. Drop it into any route of your app.
///
/// Every control is an option: turn off what your app does not need.
class SiroNavView extends StatefulWidget {
  final SiroNavController controller;
  final VoidCallback? onExit;

  /// Map style URL. Defaults to the Siro Limestone day style.
  final String styleUrl;

  /// Vehicle marker size relative to the icon (1.0 is the standard size).
  final double vehicleScale;

  /// Zoom when slow or stopped. The chase camera zooms out as speed rises and
  /// in as a maneuver gets close, like the Siro Maps app.
  final double cameraZoom;
  final double cameraTilt;

  /// Show the mute button.
  final bool showVoiceToggle;

  /// Ask for confirmation before the trip ends.
  final bool confirmEnd;

  /// Show the re-center button once the driver has moved the map.
  final bool showRecenterButton;

  /// Show "recalculating the route" while the route is being rebuilt.
  final bool showRerouteStatus;

  /// Show distance, waiting time and fare, when the trip has a [NavFareConfig].
  final bool showTripTotals;

  /// Color the route by traffic (orange slow, red heavy) from the route API.
  final bool showTraffic;

  const SiroNavView({
    super.key,
    required this.controller,
    this.onExit,
    this.styleUrl = kSiroNavDefaultStyleUrl,
    this.vehicleScale = 1.0,
    this.cameraZoom = 17.8,
    this.cameraTilt = 55.0,
    this.showVoiceToggle = true,
    this.confirmEnd = true,
    this.showRecenterButton = true,
    this.showRerouteStatus = true,
    this.showTripTotals = true,
    this.showTraffic = true,
  });

  @override
  State<SiroNavView> createState() => _SiroNavViewState();
}

class _SiroNavViewState extends State<SiroNavView> {
  SiroMapController? _map;
  bool _styleReady = false;
  Set<Polyline> _polylines = {};

  /// The camera follows the vehicle until the driver moves the map.
  bool _following = true;

  /// How many camera animations started by this view are still running. A
  /// count, not a flag: a new animation can cancel the previous one, and the
  /// cancelled one must not clear the state of the new one.
  int _animationsInFlight = 0;

  /// Where this view last asked the camera to be.
  LatLng? _commandedTarget;

  /// When the last animation of this view ended. Late camera events right after
  /// it come from the animation, not from the driver.
  DateTime _lastAnimationEnd = DateTime.fromMillisecondsSinceEpoch(0);

  /// Camera bearing, eased so curves do not make the map jerk.
  double _cameraBearing = 0;

  /// Last trustworthy heading. GPS heading is noise below walking speed.
  double _heading = 0;
  bool _hasHeading = false;

  @override
  void initState() {
    super.initState();
    _polylines = _buildPolylines(widget.controller.activeRoute);
    _listen(widget.controller);
  }

  @override
  void didUpdateWidget(covariant SiroNavView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _stopListening(oldWidget.controller);
      _listen(widget.controller);
      _onRouteChanged();
    }
  }

  @override
  void dispose() {
    _stopListening(widget.controller);
    super.dispose();
  }

  void _listen(SiroNavController controller) {
    controller.route.addListener(_onRouteChanged);
    controller.vehiclePosition.addListener(_render);
  }

  void _stopListening(SiroNavController controller) {
    controller.route.removeListener(_onRouteChanged);
    controller.vehiclePosition.removeListener(_render);
  }

  void _onRouteChanged() {
    if (!mounted) return;
    setState(() => _polylines = _buildPolylines(widget.controller.activeRoute));
  }

  /// White casing under the blue line, the same route style as the Siro app.
  Set<Polyline> _buildPolylines(NavRoute? route) {
    if (route == null || route.polyline.length < 2) return {};
    final points = route.polyline
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
    final traffic = <Polyline>{};
    final congestion = route.details?.congestion ?? const [];
    if (widget.showTraffic) {
      for (var i = 0; i < congestion.length; i++) {
        final c = congestion[i];
        if (c.level == 'normal') continue;
        final start = c.startIndex.clamp(0, points.length - 1);
        final end = c.endIndex.clamp(start, points.length - 1);
        if (end <= start) continue;
        traffic.add(Polyline(
          polylineId: PolylineId('nav_traffic_$i'),
          points: points.sublist(start, end + 1),
          color: _hexColor(c.color),
          width: 7,
        ));
      }
    }
    return {
      Polyline(
        polylineId: const PolylineId('nav_route_casing'),
        points: points,
        color: Colors.white,
        width: 11,
      ),
      Polyline(
        polylineId: const PolylineId('nav_route'),
        points: points,
        color: const Color(0xFF0071E3),
        width: 7,
      ),
      ...traffic,
    };
  }

  static Color _hexColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFFF97316) : Color(0xFF000000 | v);
  }

  /// Moves the vehicle, and the camera when it follows.
  ///
  /// The camera is a chase camera: tilted, behind the vehicle, looking ahead
  /// along the road, with the target shifted forward. The same camera the
  /// Siro Maps app uses.
  void _render() {
    final map = _map;
    final point = widget.controller.vehiclePosition.value;
    if (map == null || !_styleReady || point == null) {
      NavDiagnostics.log(
          'render skipped map=${map != null} styleReady=$_styleReady point=${point != null}');
      return;
    }

    final position = LatLng(point.latitude, point.longitude);

    // Below ~2 km/h the heading is noise, so keep the last good one.
    if (!_hasHeading || point.speedKmh >= 2.0) {
      _heading = point.heading;
      _hasHeading = true;
    }
    if (_following) {
      _cameraBearing = _lerpAngle(_cameraBearing, _heading, 0.35);
    }

    // The map is turned to the camera bearing, so the arrow is drawn at the
    // difference: pointing up while the camera keeps up with the heading.
    map.setUserMarker(Marker(
      markerId: const MarkerId('nav_vehicle'),
      position: position,
      rotation: (_heading - _cameraBearing + 360.0) % 360.0,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      icon:
          SiroBitmap.fromStyleImage(_vehicleImageId, size: widget.vehicleScale),
      zIndex: 100,
    ));

    if (_following) {
      final speed = point.speedKmh;
      final toManeuver = widget
              .controller.currentProgress.value?.distanceToNextManeuverMeters ??
          0;
      final double zoom;
      final double lookAhead;
      if (toManeuver > 0 && toManeuver < 100) {
        zoom = widget.cameraZoom + 0.2;
        lookAhead = 30;
      } else if (speed > 70) {
        final f = ((speed - 70) / 50).clamp(0.0, 1.0);
        zoom = widget.cameraZoom - 1.3 - 0.7 * f;
        lookAhead = 70 + 30 * f;
      } else if (speed > 20) {
        final f = ((speed - 20) / 50).clamp(0.0, 1.0);
        zoom = widget.cameraZoom - 0.2 - 0.8 * f;
        lookAhead = 40 + 25 * f;
      } else {
        zoom = widget.cameraZoom;
        lookAhead = 35;
      }

      final target = _offset(position, lookAhead, _cameraBearing);
      _moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
            tilt: widget.cameraTilt,
            bearing: _cameraBearing,
          ),
        ),
        target: target,
      );
    }
  }

  /// The point [meters] from [from] along [bearing] degrees.
  LatLng _offset(LatLng from, double meters, double bearing) {
    const earthRadius = 6378137.0;
    final d = meters / earthRadius;
    final lat = from.latitude * math.pi / 180;
    final lng = from.longitude * math.pi / 180;
    final b = bearing * math.pi / 180;
    final lat2 = math.asin(
      math.sin(lat) * math.cos(d) + math.cos(lat) * math.sin(d) * math.cos(b),
    );
    final lng2 = lng +
        math.atan2(
          math.sin(b) * math.sin(d) * math.cos(lat),
          math.cos(d) - math.sin(lat) * math.sin(lat2),
        );
    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  /// Eases [from] toward [to] along the shorter way around the circle.
  double _lerpAngle(double from, double to, double t) {
    final diff = ((to - from + 540) % 360) - 180;
    return (from + diff * t + 360) % 360;
  }

  /// Runs a camera animation started by this view. [target] is where the camera
  /// should end up, so a drag away from it is recognised as the driver's.
  Future<void> _moveCamera(CameraUpdate update, {LatLng? target}) async {
    final map = _map;
    if (map == null) return;
    _animationsInFlight++;
    _commandedTarget = target;
    try {
      await map.animateCamera(update);
    } finally {
      _animationsInFlight--;
      _lastAnimationEnd = DateTime.now();
    }
  }

  /// Called for every camera change. While the camera follows the vehicle, a
  /// centre far from the last commanded target means the driver dragged the map.
  void _onCameraMoved(CameraPosition camera) {
    final target = _commandedTarget;
    if (!_following || _animationsInFlight > 0 || target == null) return;
    if (DateTime.now().difference(_lastAnimationEnd).inMilliseconds < 500)
      return;
    final moved =
        NavPoint.fromLatLng(camera.target.latitude, camera.target.longitude)
            .distanceTo(NavPoint.fromLatLng(target.latitude, target.longitude));
    if (moved > _dragDetectMeters) {
      NavDiagnostics.log(
          'follow off: camera moved ${moved.round()} m from target');
      setState(() => _following = false);
    }
  }

  /// The map reports the start of a camera move once per sequence. When none of
  /// this view's animations is running, the move is the driver's finger.
  void _onCameraMoveStarted() {
    if (!_following || _animationsInFlight > 0 || _commandedTarget == null)
      return;
    if (DateTime.now().difference(_lastAnimationEnd).inMilliseconds < 500)
      return;
    NavDiagnostics.log('follow off: camera move started by the driver');
    setState(() => _following = false);
  }

  void _recenter() {
    setState(() => _following = true);
    _render();
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;

    // The style reload clears images, so the vehicle icon is added every time.
    final icon = await NavVehicleIcon.render();
    await map.addImage(_vehicleImageId, icon);
    await NavStyleIcons.addAll(map);
    _styleReady = true;
    NavDiagnostics.log('style ready');

    if (widget.controller.vehiclePosition.value == null) {
      _fitRoute();
    }
    _render();
  }

  void _fitRoute() {
    final route = widget.controller.activeRoute;
    if (route == null || route.polyline.length < 2) return;

    var south = route.polyline.first.latitude;
    var north = south;
    var west = route.polyline.first.longitude;
    var east = west;
    for (final p in route.polyline) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
    _moveCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      ),
      left: 48,
      top: 160,
      right: 48,
      bottom: 220,
    ));
  }

  /// The instruction is announced once, so its distance is stale after that.
  /// Progress updates carry the live distance to the same maneuver.
  InstructionEvent? _withLiveDistance(
      InstructionEvent? instruction, ProgressEvent? progress) {
    if (instruction == null || progress == null) return instruction;
    if (progress.currentStepIndex != instruction.stepIndex) return instruction;
    return InstructionEvent(
      stepIndex: instruction.stepIndex,
      instruction: instruction.instruction,
      streetName: instruction.streetName,
      maneuverType: instruction.maneuverType,
      exitNumber: instruction.exitNumber,
      distanceMeters: progress.distanceToNextManeuverMeters,
      timeSeconds: instruction.timeSeconds,
      priority: instruction.priority,
      ttlSeconds: instruction.ttlSeconds,
    );
  }

  Future<void> _endTrip() async {
    if (widget.confirmEnd) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إنهاء الرحلة؟'),
          content:
              const Text('يتوقف التوجيه والصوت والمسار. هل تبي تنهي الرحلة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('متابعة'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('إنهاء'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await widget.controller.stopNavigation();
    widget.onExit?.call();
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _totalsText(NavTripTotals totals) {
    final km = totals.distanceKm.toStringAsFixed(2);
    final waiting = totals.waitingMinutes.round();
    final leg = widget.controller.phase.value.labelAr;
    return '$leg  •  $km كم  •  انتظار $waiting د  •  ${totals.fareLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SiroMap(
            apiKey: controller.config.apiKey,
            styleUrl: widget.styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(31.9539, 35.9106),
              zoom: 16.0,
              tilt: 45.0,
            ),
            polylines: _polylines,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            onMapCreated: (mapCtrl) => _map = mapCtrl,
            onStyleLoaded: _onStyleLoaded,
            onCameraMove: _onCameraMoved,
            onCameraMoveStarted: _onCameraMoveStarted,
          ),

          // Top guidance banner, with the live distance to the maneuver
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ValueListenableBuilder<InstructionEvent?>(
                valueListenable: controller.currentInstruction,
                builder: (context, instruction, _) {
                  return ValueListenableBuilder<ProgressEvent?>(
                    valueListenable: controller.currentProgress,
                    builder: (context, progress, _) {
                      return NavInstructionBanner(
                        instruction: _withLiveDistance(instruction, progress),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Reroute status and trip totals, under the banner
          Positioned(
            top: 190,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showRerouteStatus)
                  ValueListenableBuilder<bool>(
                    valueListenable: controller.isRerouting,
                    builder: (context, rerouting, _) => rerouting
                        ? _pill('جاري إعادة احتساب المسار…')
                        : const SizedBox.shrink(),
                  ),
                if (widget.showRerouteStatus) const SizedBox(height: 8),
                if (widget.showTripTotals)
                  ValueListenableBuilder<NavTripTotals?>(
                    valueListenable: controller.tripTotals,
                    builder: (context, totals, _) => totals == null
                        ? const SizedBox.shrink()
                        : _pill(_totalsText(totals)),
                  ),
              ],
            ),
          ),

          // Speed and upcoming camera HUD
          Positioned(
            left: 16,
            bottom: 150,
            child: ValueListenableBuilder<double>(
              valueListenable: controller.currentSpeedKmh,
              builder: (context, speed, _) {
                return ValueListenableBuilder<SpeedCameraEvent?>(
                  valueListenable: controller.upcomingCamera,
                  builder: (context, camera, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: controller.isOverspeeding,
                      builder: (context, overspeed, _) {
                        return NavSpeedBadge(
                          currentSpeedKmh: speed,
                          upcomingCamera: camera,
                          isOverspeeding: overspeed,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Map controls on the right, above the bottom bar
          Positioned(
            right: 16,
            bottom: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showRecenterButton)
                  ValueListenableBuilder<NavPoint?>(
                    valueListenable: controller.vehiclePosition,
                    builder: (context, _, __) => _following
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FloatingActionButton.small(
                              heroTag: null,
                              tooltip: 'إعادة التوسيط',
                              backgroundColor: Colors.white,
                              onPressed: _recenter,
                              child: const Icon(Icons.my_location,
                                  color: Color(0xFF0071E3)),
                            ),
                          ),
                  ),
                if (widget.showVoiceToggle)
                  ValueListenableBuilder<bool>(
                    valueListenable: controller.voiceMuted,
                    builder: (context, muted, _) {
                      return FloatingActionButton.small(
                        heroTag: null,
                        tooltip: muted ? 'تشغيل الصوت' : 'إيقاف الصوت',
                        backgroundColor: Colors.white,
                        onPressed: () => controller.setVoiceMuted(!muted),
                        child: Icon(
                          muted ? Icons.volume_off : Icons.volume_up,
                          color: const Color(0xFF0071E3),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Bottom trip metrics bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<ProgressEvent?>(
              valueListenable: controller.currentProgress,
              builder: (context, progress, _) {
                return NavBottomBar(
                  progress: progress,
                  onStopNavigation: _endTrip,
                );
              },
            ),
          ),

          // Error overlay for licensing, routing or GPS failures
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: ValueListenableBuilder<String?>(
              valueListenable: controller.activeError,
              builder: (context, error, _) {
                if (error == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
