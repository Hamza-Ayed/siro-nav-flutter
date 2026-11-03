// وظيفة الملف: تنفيذ أو إعداد siro map widget ضمن هذا الجزء من المشروع.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'siro_map_controller.dart';
import 'offline_service.dart';
import 'telemetry_service.dart';
import 'models/geometry.dart';
import 'models/types.dart';

/// A widget displaying an Siro map.
///
/// ## Drop-in replacement for `GoogleMap`
///
/// ```dart
/// // Before (Google Maps Flutter)
/// GoogleMap(
///   initialCameraPosition: CameraPosition(target: LatLng(33.5, 36.2), zoom: 14),
///   markers: _markers,
///   onMapCreated: (ctrl) => _controller = ctrl,
/// )
///
/// // After (Siro Maps)
/// SiroMap(
///   apiKey: 'YOUR_KEY',
///   initialCameraPosition: CameraPosition(target: LatLng(33.5, 36.2), zoom: 14),
///   markers: _markers,
///   onMapCreated: (ctrl) => _controller = ctrl,
/// )
/// ```
///
/// All overlay collections ([markers], [polylines], [circles], [polygons])
/// are **declarative**: just call `setState` with a new `Set` and the map
/// will reconcile additions, updates, and removals automatically.
class SiroMap extends StatefulWidget {
  const SiroMap({
    super.key,
    required this.apiKey,
    required this.initialCameraPosition,
    this.mapType = SiroMapType.normal,
    this.styleUrl,
    this.markers = const {},
    this.polylines = const {},
    this.circles = const {},
    this.polygons = const {},

    this.onLongPress,
    this.onMapCreated,
    this.onStyleLoaded,
    this.onTap,
    this.onCameraMove,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.compassEnabled = false,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.autoCache = false,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.cameraTargetBounds = CameraTargetBounds.unbounded,
  });

  // ── Required ───────────────────────────────────────────────

  /// Your Siro Maps API key.
  final String apiKey;

  /// Starting camera position (target + zoom).
  final CameraPosition initialCameraPosition;

  // ── Map style ──────────────────────────────────────────────

  /// Base tile style. Ignored when [styleUrl] is provided.
  final SiroMapType mapType;

  /// Override with a custom MapLibre style URL.
  final String? styleUrl;

  /// Automatically download tiles around the camera center when idle.
  final bool autoCache;

  // ── Overlays (declarative — mirrors GoogleMap) ─────────────

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final Set<Polygon> polygons;

  // ── Lifecycle callbacks ────────────────────────────────────

  /// Called once the map is ready. Use [SiroMapController] for all operations.
  final MapCreatedCallback? onMapCreated;

  /// Note: If this callback returns a Future, the widget will await it before
  /// adding declarative markers and polylines.
  final Function()? onStyleLoaded;

  // ── Interaction callbacks ──────────────────────────────────

  /// Called when the user taps the map (not on a marker).
  final ArgumentCallback<mgl.LatLng>? onTap;

  /// Called on a long-press on the map.
  final ArgumentCallback<mgl.LatLng>? onLongPress;

  /// Called repeatedly while the camera is moving.
  final CameraPositionCallback? onCameraMove;

  /// Called when the camera starts moving.
  final VoidCallback? onCameraMoveStarted;

  /// Called when the camera becomes idle.
  final VoidCallback? onCameraIdle;

  // ── UI controls ────────────────────────────────────────────

  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool compassEnabled;

  // ── Gesture controls ───────────────────────────────────────

  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool zoomGesturesEnabled;

  // ── Camera constraints ─────────────────────────────────────

  final MinMaxZoomPreference minMaxZoomPreference;
  final CameraTargetBounds cameraTargetBounds;

  @override
  State<SiroMap> createState() => _SiroMapState();
}

class _SiroMapState extends State<SiroMap> {
  SiroMapController? _controller;
  bool _isCameraMoving = false;
  String? _styleString;
  bool _isLoadingStyle = true;
  bool _isNativeStyleLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.apiKey.isNotEmpty) {
      SiroTelemetryService.instance.initialize(apiKey: widget.apiKey);
    }
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final url = _resolvedStyleUrl;
      print("🔥 [SiroMap] Resolving style: $url");

      if (url.startsWith('{')) {
        _styleString = url;
      } else if (url.startsWith('asset://') || url.startsWith('assets/') || (url.endsWith('.json') && !url.startsWith('http'))) {
        final assetPath = url.replaceFirst('asset://', '');
        try {
          _styleString = await rootBundle.loadString(assetPath);
          print("🔥 [SiroMap] Style loaded from asset string: ${assetPath.split('/').last}");
        } catch (_) {
          try {
            _styleString = await rootBundle.loadString('packages/siro_map/$assetPath');
            print("🔥 [SiroMap] Style loaded from package asset: packages/siro_map/$assetPath");
          } catch (_) {
            try {
              _styleString = await rootBundle.loadString('packages/siro_map/$assetPath');
              print("🔥 [SiroMap] Style loaded from package asset: packages/siro_map/$assetPath");
            } catch (e) {
              print("❌ [SiroMap] Asset load failed: $e");
              _styleString = url;
            }
          }
        }
      } else if (url.startsWith('file://')) {
        final filePath = url.replaceFirst('file://', '');
        final file = File(filePath);
        if (await file.exists()) {
          _styleString = await file.readAsString();
          print("🔥 [SiroMap] Style loaded from local file: $filePath");
        } else {
          _styleString = url;
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        // If satellite theme requested, use bundled ESRI Satellite hybrid style directly
        if (widget.mapType == SiroMapType.satellite || url.contains('theme=satellite')) {
          try {
            _styleString = await rootBundle.loadString('packages/siro_map/assets/style-satellite.json');
            print("🛰️ [SiroMap] Loaded bundled ESRI Satellite hybrid style successfully");
            return;
          } catch (_) {
            try {
              _styleString = await rootBundle.loadString('assets/style-satellite.json');
              print("🛰️ [SiroMap] Loaded local ESRI Satellite hybrid style successfully");
              return;
            } catch (_) {}
          }
        }
        if (widget.mapType == SiroMapType.terrain || url.contains('terrain')) {
          try {
            _styleString = await rootBundle.loadString('packages/siro_map/assets/style-3d-terrain.json');
            print("🏔️ [SiroMap] Loaded bundled 3D Terrain style successfully");
            return;
          } catch (_) {
            try {
              _styleString = await rootBundle.loadString('assets/style-3d-terrain.json');
              print("🏔️ [SiroMap] Loaded local 3D Terrain style successfully");
              return;
            } catch (_) {}
          }
        }
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200 && res.body.trim().startsWith('{')) {
            _styleString = res.body;
            print("🔥 [SiroMap] Pre-fetched remote style JSON (${res.body.length} bytes)");
          } else {
            _styleString = url;
          }
        } catch (netErr) {
          print("⚠️ [SiroMap] Direct HTTP fetch failed ($netErr), attempting bundled fallback");
          try {
            final fallback = (widget.mapType == SiroMapType.satellite || url.contains('theme=satellite'))
                ? 'packages/siro_map/assets/style-satellite.json'
                : (widget.mapType == SiroMapType.terrain || url.contains('terrain'))
                    ? 'packages/siro_map/assets/style-3d-terrain.json'
                    : 'packages/siro_map/assets/style.json';
            _styleString = await rootBundle.loadString(fallback);
            print("🔥 [SiroMap] Loaded bundled offline fallback style successfully: $fallback");
          } catch (_) {
            _styleString = url;
          }
        }
      } else {
        // Fallback: try rootBundle first
        try {
          _styleString = await rootBundle.loadString(url);
          print("🔥 [SiroMap] Style loaded from rootBundle fallback: $url");
        } catch (_) {
          _styleString = url;
        }
      }
    } catch (e) {
      print("❌ [SiroMap] Failed to load style: $e");
      _styleString = 'about:blank';
    } finally {
      if (mounted) {
        setState(() => _isLoadingStyle = false);
      }
    }
  }

  @override
  void didUpdateWidget(SiroMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mapType != widget.mapType ||
        oldWidget.styleUrl != widget.styleUrl) {
      _isNativeStyleLoaded = false;
      _loadStyle();
    }

    final ctrl = _controller;
    if (ctrl == null || !_isNativeStyleLoaded) return;

    // Reconcile each overlay set when widget rebuilds.
    ctrl.diffMarkers(oldWidget.markers, widget.markers);
    ctrl.diffPolylines(oldWidget.polylines, widget.polylines);
    ctrl.diffCircles(oldWidget.circles, widget.circles);
    ctrl.diffPolygons(oldWidget.polygons, widget.polygons);
  }

  String get _resolvedStyleUrl {
    if (widget.styleUrl != null) return widget.styleUrl!;
    // Default to local assets for instant loading and 100% offline support (as in Siro Rider)
    return switch (widget.mapType) {
      SiroMapType.normal => 'asset://packages/siro_map/assets/style_dark.json',
      SiroMapType.light => 'asset://packages/siro_map/assets/style.json',
      SiroMapType.satellite => 'asset://packages/siro_map/assets/style-satellite.json',
      SiroMapType.terrain => 'asset://packages/siro_map/assets/style-3d-terrain.json',
      SiroMapType.none => 'about:blank',
    };
  }

  Future<void> _onMapCreated(mgl.MapLibreMapController rawCtrl) async {
    print("🗺️ [SiroMapWidget] _onMapCreated: Native MapLibre controller attached.");
    rawCtrl.onSymbolTapped.add(_onSymbolTapped);
    rawCtrl.onLineTapped.add(_onLineTapped);

    final ctrl = await SiroMapController.create(
      raw: rawCtrl,
      apiKey: widget.apiKey,
    );
    _controller = ctrl;
    print("🗺️ [SiroMapWidget] Invoking widget.onMapCreated callback...");
    widget.onMapCreated?.call(ctrl);

    // The style can finish loading while the controller above is still being
    // created (it awaits an image). That early call found no controller and
    // returned, so replay it now, or onStyleLoaded never reaches the widget.
    if (_isNativeStyleLoaded) {
      print("🎨 [SiroMapWidget] Style loaded before the controller; replaying onStyleLoaded.");
      await _onStyleLoaded();
    }
  }

  void _onSymbolTapped(mgl.Symbol symbol) =>
      _controller?.onSymbolTapped(symbol);

  void _onLineTapped(mgl.Line line) => _controller?.onLineTapped(line);

  Future<void> _onStyleLoaded() async {
    print("🎨 [SiroMapWidget] _onStyleLoaded: MapLibre native style finished loading.");
    _isNativeStyleLoaded = true;
    final ctrl = _controller;
    if (ctrl == null) {
      print("⚠️ [SiroMapWidget] _onStyleLoaded: _controller is null!");
      return;
    }

    await ctrl.onStyleLoaded();
    print("🎨 [SiroMapWidget] Invoking widget.onStyleLoaded callback...");
    final callbackResult = widget.onStyleLoaded?.call();
    if (callbackResult is Future) {
      await callbackResult;
    }

    print("📌 [SiroMapWidget] Re-rendering overlays: markers=${widget.markers.length}, polylines=${widget.polylines.length}, circles=${widget.circles.length}, polygons=${widget.polygons.length}");
    for (final m in widget.markers) await ctrl.addMarker(m);
    for (final p in widget.polylines) await ctrl.addPolyline(p);
    for (final c in widget.circles) await ctrl.addCircle(c);
    for (final g in widget.polygons) await ctrl.addPolygon(g);
    
    // Apply defaults AFTER markers have initialized the symbol layer
    await ctrl.applyMarkerVisibilityDefaults();

    // Safely refresh to enable native location layer after style is ready on iOS
    if (widget.myLocationEnabled && mounted) {
      print("📍 [SiroMapWidget] Enabling native location layer after style is loaded.");
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStyle) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool canEnableLocation = _isNativeStyleLoaded && widget.myLocationEnabled;

    return mgl.MapLibreMap(
      styleString: _styleString!,
      initialCameraPosition: widget.initialCameraPosition.toMapLibre(),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: widget.onTap != null
          ? (point, latlng) => widget.onTap!(latlng)
          : null,
      onMapLongClick: widget.onLongPress != null
          ? (point, latlng) => widget.onLongPress!(latlng)
          : null,
      onCameraIdle: () {
        _isCameraMoving = false;
        final url = _resolvedStyleUrl;
        final isRemote = url.startsWith('http://') || url.startsWith('https://');
        if (widget.autoCache && isRemote) {
          final pos = _controller?.cameraPosition;
          if (pos != null) {
            SiroOfflineService.instance.downloadRegion(
              pos.target,
              styleUrl: url,
            );
          }
        }
        widget.onCameraIdle?.call();
      },
      onCameraTrackingChanged: null,
      myLocationEnabled: canEnableLocation,
      myLocationRenderMode: canEnableLocation
          ? mgl.MyLocationRenderMode.normal
          : mgl.MyLocationRenderMode.normal,
      myLocationTrackingMode: mgl.MyLocationTrackingMode.none,
      compassEnabled: widget.compassEnabled,
      rotateGesturesEnabled: widget.rotateGesturesEnabled,
      scrollGesturesEnabled: widget.scrollGesturesEnabled,
      tiltGesturesEnabled: widget.tiltGesturesEnabled,
      zoomGesturesEnabled: widget.zoomGesturesEnabled,
      minMaxZoomPreference: mgl.MinMaxZoomPreference(
        widget.minMaxZoomPreference.minZoom,
        widget.minMaxZoomPreference.maxZoom,
      ),
      cameraTargetBounds: widget.cameraTargetBounds.bounds != null
          ? mgl.CameraTargetBounds(widget.cameraTargetBounds.bounds!)
          : mgl.CameraTargetBounds.unbounded,
      trackCameraPosition:
          widget.onCameraMove != null ||
              widget.onCameraMoveStarted != null ||
              widget.onCameraIdle != null,
      onCameraMove: (pos) {
        if (!_isCameraMoving && widget.onCameraMoveStarted != null) {
          _isCameraMoving = true;
          widget.onCameraMoveStarted!();
        }
        widget.onCameraMove?.call(CameraPosition.fromMapLibre(pos));
      },
      onCameraTrackingDismissed: null,
    );
  }
}

/// Backward compatibility alias for developers migrating from `google_maps_flutter`.
typedef GoogleMap = SiroMap;


