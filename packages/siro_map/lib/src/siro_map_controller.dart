// وظيفة الملف: تنفيذ أو إعداد siro map controller ضمن هذا الجزء من المشروع.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'models/geometry.dart';
import 'models/bitmap.dart';
import 'models/types.dart';

/// Controls a live [SiroMap] widget.
///
/// Obtain a reference via the [SiroMap.onMapCreated] callback.
/// This API mirrors [GoogleMapController] from `google_maps_flutter`.
class SiroMapController {
  SiroMapController._({
    required mgl.MapLibreMapController raw,
    required String apiKey,
  })  : _raw = raw,
        _apiKey = apiKey;

  final mgl.MapLibreMapController _raw;
  final String _apiKey;

  // ── Internal object registries ─────────────────────────────

  /// Maps our [MarkerId] → the live MapLibre [mgl.Symbol].
  final Map<MarkerId, mgl.Symbol> _symbols = {};

  /// Reverse map: MapLibre symbol id → our [Marker] (for tap routing).
  final Map<String, Marker> _symbolToMarker = {};

  /// Maps our [PolylineId] → live MapLibre [mgl.Line].
  final Map<PolylineId, mgl.Line> _lines = {};
  final Map<String, Polyline> _lineToPolyline = {};

  /// Maps our [CircleId] → live MapLibre [mgl.Circle].
  final Map<CircleId, mgl.Circle> _circles = {};

  /// Maps our [PolygonId] → live MapLibre [mgl.Fill].
  final Map<PolygonId, mgl.Fill> _fills = {};

  /// A single, imperatively-managed "user location" symbol (the moving puck).
  /// Kept OUT of the declarative [Marker] sets so it can be updated on every
  /// GPS / animation tick without rebuilding the widget tree — see
  /// [setUserMarker]. Reset to null on style reload (native symbol is
  /// destroyed) so the next update re-adds it.
  mgl.Symbol? _userSymbol;
  Marker? _pendingUserMarker;
  bool _userSymbolBusy = false;
  bool _isStyleLoaded = false;
  CameraUpdate? _pendingCameraUpdate;
  bool _pendingCameraAnimated = true;

  // ── Factory / init ─────────────────────────────────────────

  static Future<SiroMapController> create({
    required mgl.MapLibreMapController raw,
    required String apiKey,
  }) async {
    final ctrl = SiroMapController._(raw: raw, apiKey: apiKey);
    await ctrl._registerDefaultImages();
    return ctrl;
  }

  /// Pre-loads built-in marker images into the map style.
  Future<void> _registerDefaultImages() async {
    try {
      final bytes = await rootBundle
          .load('packages/siro_map/assets/markers/default.png');
      await _raw.addImage('siro-marker-default', bytes.buffer.asUint8List());
      return;
    } catch (_) {}
    try {
      final bytes = await rootBundle
          .load('packages/siro_map/assets/markers/default.png');
      await _raw.addImage('siro-marker-default', bytes.buffer.asUint8List());
    } catch (_) {
      // Asset not found — developer can register their own via addImage().
    }
  }

  /// Called by the widget when the map style has finished loading/reloading.
  /// We clear internal registries because native objects (Symbols, Lines)
  /// are destroyed on style reload.
  Future<void> onStyleLoaded() async {
    _isStyleLoaded = true;
    _symbols.clear();
    _symbolToMarker.clear();
    _lines.clear();
    _lineToPolyline.clear();
    _circles.clear();
    _fills.clear();
    _loadedImages.clear();
    // The user-location symbol is destroyed with the old style; forget the
    // stale handle so the next [setUserMarker] call re-creates it.
    _userSymbol = null;
    await _registerDefaultImages();
    await applyMarkerVisibilityDefaults();

    // Safely execute camera updates queued before style finished rendering
    if (_pendingCameraUpdate != null) {
      final pending = _pendingCameraUpdate!;
      final animated = _pendingCameraAnimated;
      _pendingCameraUpdate = null;
      print("🎬 [SiroController] Style loaded! Flushing queued camera update (animated=$animated)...");
      try {
        if (animated) {
          await _raw.animateCamera(pending.toMapLibre());
        } else {
          await _raw.moveCamera(pending.toMapLibre());
        }
        print("✅ [SiroController] Queued camera update executed successfully.");
      } catch (e) {
        print("⚠️ [SiroController] Queued camera update trapped error: $e");
      }
    }
  }

  /// Google Maps draws every marker unconditionally, but MapLibre's symbol
  /// layer defaults to `icon-allow-overlap = false`, so custom markers get
  /// collision-culled against the basemap's place labels and silently vanish.
  ///
  /// To match `GoogleMap` semantics (this SDK is a drop-in replacement) we opt
  /// marker *icons* out of collision. The symbol manager is created before
  /// `onStyleLoadedCallback` fires, so applying this here — before any markers
  /// are (re)added on style load — makes pins reliably visible and keeps them
  /// visible across dark/light style reloads.
  ///
  /// Only the icon is forced to always draw; the optional info-window text is
  /// left collision-managed so a marker whose artwork already contains a label
  /// (e.g. the A/B route pins) doesn't render a duplicate text glyph on top.
  Future<void> applyMarkerVisibilityDefaults() async {
    try {
      await _raw.setSymbolIconAllowOverlap(true);
      await _raw.setSymbolIconIgnorePlacement(true);
    } catch (_) {
      // Symbol manager not ready yet — safe to ignore; defaults reapply on the
      // next style load.
    }
  }

  // ── Camera  (same API as GoogleMapController) ──────────────

  /// Animates the camera to the given [update]. Safe on iOS before style is loaded.
  Future<bool?> animateCamera(CameraUpdate update) async {
    if (!_isStyleLoaded) {
      print("⏳ [SiroController] animateCamera: Style not loaded yet. Queuing camera update safely.");
      _pendingCameraUpdate = update;
      _pendingCameraAnimated = true;
      return null;
    }
    try {
      print("🎬 [SiroController] animateCamera: Executing native animation now.");
      return await _raw.animateCamera(update.toMapLibre());
    } catch (e) {
      print("⚠️ [SiroController] animateCamera native call error: $e. Re-queuing.");
      _pendingCameraUpdate = update;
      _pendingCameraAnimated = true;
      return null;
    }
  }

  /// Instantly moves the camera to the given [update]. Safe on iOS before style is loaded.
  Future<bool?> moveCamera(CameraUpdate update) async {
    if (!_isStyleLoaded) {
      print("⏳ [SiroController] moveCamera: Style not loaded yet. Queuing camera update safely.");
      _pendingCameraUpdate = update;
      _pendingCameraAnimated = false;
      return null;
    }
    try {
      print("🎬 [SiroController] moveCamera: Executing native move now.");
      return await _raw.moveCamera(update.toMapLibre());
    } catch (e) {
      print("⚠️ [SiroController] moveCamera native call error: $e. Re-queuing.");
      _pendingCameraUpdate = update;
      _pendingCameraAnimated = false;
      return null;
    }
  }

  /// Returns the current [CameraPosition] of the map.
  CameraPosition? get cameraPosition => _raw.cameraPosition != null
      ? CameraPosition.fromMapLibre(_raw.cameraPosition!)
      : null;

  /// Direct access to underlying MapLibreMapController.
  mgl.MapLibreMapController get raw => _raw;

  /// Sets camera tilt (0.0 to 60.0 degrees) smoothly.
  Future<void> setTilt(double tilt, {Duration duration = const Duration(milliseconds: 300)}) async {
    final pos = cameraPosition;
    if (pos == null) return;
    await _raw.animateCamera(
      mgl.CameraUpdate.newCameraPosition(
        mgl.CameraPosition(
          target: pos.target,
          zoom: pos.zoom,
          bearing: pos.bearing,
          tilt: tilt.clamp(0.0, 60.0),
        ),
      ),
      duration: duration,
    );
  }

  /// Sets camera bearing (0.0 to 360.0 degrees) smoothly.
  Future<void> setBearing(double bearing, {Duration duration = const Duration(milliseconds: 100)}) async {
    final pos = cameraPosition;
    if (pos == null) return;
    await _raw.animateCamera(
      mgl.CameraUpdate.newCameraPosition(
        mgl.CameraPosition(
          target: pos.target,
          zoom: pos.zoom,
          bearing: (bearing % 360.0 + 360.0) % 360.0,
          tilt: pos.tilt,
        ),
      ),
      duration: duration,
    );
  }

  /// Smooth cinematic orbit step by [deltaDegrees].
  Future<void> orbitStep(double deltaDegrees, {Duration duration = const Duration(milliseconds: 60)}) async {
    final pos = cameraPosition;
    if (pos == null) return;
    final newBearing = (pos.bearing + deltaDegrees) % 360.0;
    await _raw.animateCamera(
      mgl.CameraUpdate.newCameraPosition(
        mgl.CameraPosition(
          target: pos.target,
          zoom: pos.zoom,
          bearing: newBearing,
          tilt: pos.tilt,
        ),
      ),
      duration: duration,
    );
  }

  /// Sets layer visibility in the active style.
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    if (!_isStyleLoaded) return;
    try {
      await _raw.setLayerVisibility(layerId, visible);
    } catch (e) {
      print("⚠️ [SiroController] setLayerVisibility error for $layerId: $e");
    }
  }

  /// Updates sun lighting and shadows simulation across terrain and 3D buildings.
  Future<void> updateSunSimulation({
    required double sunAzimuth,
    required String shadowColorHex,
    required String highlightColorHex,
    required String buildingColorHex,
    double buildingOpacity = 0.88,
    double hillshadeExaggeration = 0.75,
  }) async {
    if (!_isStyleLoaded) return;
    try {
      final hillshadeProps = mgl.HillshadeLayerProperties(
        hillshadeIlluminationDirection: sunAzimuth % 360.0,
        hillshadeShadowColor: shadowColorHex,
        hillshadeHighlightColor: highlightColorHex,
        hillshadeExaggeration: hillshadeExaggeration,
      );
      try {
        await _raw.setLayerProperties('hillshading', hillshadeProps);
      } catch (_) {}
      try {
        await _raw.setLayerProperties('terrain-3d-hillshading', hillshadeProps);
      } catch (_) {}
    } catch (_) {}

    try {
      final buildingProps = mgl.FillExtrusionLayerProperties(
        fillExtrusionColor: buildingColorHex,
        fillExtrusionOpacity: buildingOpacity,
      );
      await _raw.setLayerProperties('building-3d', buildingProps);
      await _raw.setLayerProperties('building-3d-osm', buildingProps);
    } catch (_) {}
  }

  /// Returns the current zoom level.
  Future<double> getZoomLevel() async => _raw.cameraPosition?.zoom ?? 14.0;

  /// Returns the [mgl.LatLng] visible at screen coordinate [point].
  Future<mgl.LatLng> getLatLng(Point<double> point) =>
      _raw.toLatLng(Point(point.x, point.y));

  /// Returns the screen coordinate of the given [latLng].
  Future<Point<num>> getScreenCoordinate(mgl.LatLng latLng) =>
      _raw.toScreenLocation(latLng);

  /// Returns the current visible region as [mgl.LatLngBounds].
  Future<mgl.LatLngBounds> getVisibleRegion() => _raw.getVisibleRegion();

  // ── Map images ─────────────────────────────────────────────

  /// Register a custom image into the map.
  /// Required before using [SiroBitmap.fromBytes] or custom style images.
  Future<void> addImage(String imageId, Uint8List bytes) async {
    await _raw.addImage(imageId, bytes);
    _loadedImages.add(imageId);
  }

  /// Adds a single [Marker] to the map and returns its MapLibre handle.
  Future<mgl.Symbol?> addMarker(Marker marker) async {
    if (!_isStyleLoaded) return null;
    try {
      if (_symbols.containsKey(marker.markerId)) {
        await _updateMarker(marker);
        return _symbols[marker.markerId];
      }
      await _loadBitmapIfNeeded(marker.icon);
      final symbol = await _raw.addSymbol(marker.toSymbolOptions());
      _symbols[marker.markerId] = symbol;
      _symbolToMarker[symbol.id] = marker;

      // Ensure collision defaults apply (symbol layer is created lazily by MapLibre)
      await applyMarkerVisibilityDefaults();
      return symbol;
    } catch (e) {
      print("⚠️ [SiroMapController] addMarker failed for ${marker.markerId.value}: $e");
      return null;
    }
  }

  /// Updates an existing marker's position / appearance.
  Future<void> _updateMarker(Marker marker) async {
    if (!_isStyleLoaded) return;
    final symbol = _symbols[marker.markerId];
    if (symbol == null) {
      await addMarker(marker);
      return;
    }
    try {
      await _loadBitmapIfNeeded(marker.icon);
      await _raw.updateSymbol(symbol, marker.toSymbolOptions());
      _symbolToMarker[symbol.id] = marker;
    } catch (e) {
      print("⚠️ [SiroMapController] _updateMarker failed for ${marker.markerId.value}: $e");
    }
  }

  /// Removes a marker by its [MarkerId].
  Future<void> _removeMarker(MarkerId id) async {
    final symbol = _symbols.remove(id);
    if (symbol == null) return;
    _symbolToMarker.remove(symbol.id);
    try {
      await _raw.removeSymbol(symbol);
    } catch (_) {}
  }

  /// Removes a marker from the map by its [MarkerId].
  Future<void> removeMarker(MarkerId id) => _removeMarker(id);

  /// Removes a polyline from the map by its [PolylineId].
  Future<void> removePolyline(PolylineId id) => _removePolyline(id);

  // ── User-location puck (imperative, high-frequency) ────────

  /// Places or moves the single "user location" puck.
  ///
  /// Unlike the declarative [markers] set, this updates one native symbol
  /// in place — the correct pattern for a marker that moves on every GPS or
  /// animation frame (a vehicle/heading puck). It avoids rebuilding the
  /// Flutter tree and the whole-set diff, which otherwise makes a
  /// continuously-moving marker flicker or disappear.
  ///
  /// Safe to call at up to display refresh rate: overlapping calls are
  /// coalesced (a call that arrives while another is still in flight is
  /// dropped, and the next tick supplies fresh coordinates). The puck is
  /// re-created automatically after a style reload.
  Future<void> setUserMarker(Marker marker) async {
    if (!_isStyleLoaded) return;
    _pendingUserMarker = marker;
    if (_userSymbolBusy) return;
    _userSymbolBusy = true;
    try {
      while (_pendingUserMarker != null) {
        final m = _pendingUserMarker!;
        _pendingUserMarker = null;
        await _loadBitmapIfNeeded(m.icon);
        final symbol = _userSymbol;
        if (symbol == null) {
          _userSymbol = await _raw.addSymbol(m.toSymbolOptions());
        } else {
          await _raw.updateSymbol(symbol, m.toSymbolOptions());
        }
      }
    } catch (_) {
    } finally {
      _userSymbolBusy = false;
    }
  }

  /// Removes the user-location puck, if present.
  Future<void> clearUserMarker() async {
    final symbol = _userSymbol;
    if (symbol == null) return;
    _userSymbol = null;
    try {
      await _raw.removeSymbol(symbol);
    } catch (_) {}
  }

  // ── Polylines ──────────────────────────────────────────────

  Future<mgl.Line?> addPolyline(Polyline polyline) async {
    if (!_isStyleLoaded) return null;
    try {
      final line = await _raw.addLine(polyline.toLineOptions());
      _lines[polyline.polylineId] = line;
      _lineToPolyline[line.id] = polyline;
      return line;
    } catch (_) {
      return null;
    }
  }

  Future<void> _updatePolyline(Polyline polyline) async {
    if (!_isStyleLoaded) return;
    final line = _lines[polyline.polylineId];
    if (line == null) return;
    try {
      await _raw.updateLine(line, polyline.toLineOptions());
      _lineToPolyline[line.id] = polyline;
    } catch (_) {}
  }

  Future<void> _removePolyline(PolylineId id) async {
    final line = _lines.remove(id);
    if (line == null) return;
    _lineToPolyline.remove(line.id);
    try {
      await _raw.removeLine(line);
    } catch (_) {}
  }

  // ── Circles ────────────────────────────────────────────────

  Future<void> addCircle(Circle circle) async {
    if (!_isStyleLoaded) return;
    try {
      final c = await _raw.addCircle(circle.toCircleOptions());
      _circles[circle.circleId] = c;
    } catch (_) {}
  }

  Future<void> _updateCircle(Circle circle) async {
    if (!_isStyleLoaded) return;
    final c = _circles[circle.circleId];
    if (c == null) return;
    try {
      await _raw.updateCircle(c, circle.toCircleOptions());
    } catch (_) {}
  }

  Future<void> _removeCircle(CircleId id) async {
    final c = _circles.remove(id);
    if (c == null) return;
    try {
      await _raw.removeCircle(c);
    } catch (_) {}
  }

  // ── Polygons ───────────────────────────────────────────────

  Future<void> addPolygon(Polygon polygon) async {
    if (!_isStyleLoaded) return;
    try {
      final fill = await _raw.addFill(polygon.toFillOptions());
      _fills[polygon.polygonId] = fill;
    } catch (_) {}
  }

  Future<void> _updatePolygon(Polygon polygon) async {
    if (!_isStyleLoaded) return;
    final fill = _fills[polygon.polygonId];
    if (fill == null) return;
    try {
      await _raw.updateFill(fill, polygon.toFillOptions());
    } catch (_) {}
  }

  Future<void> _removePolygon(PolygonId id) async {
    final fill = _fills.remove(id);
    if (fill == null) return;
    try {
      await _raw.removeFill(fill);
    } catch (_) {}
  }

  // ── Tap routing ────────────────────────────────────────────

  void onSymbolTapped(mgl.Symbol symbol) {
    final marker = _symbolToMarker[symbol.id];
    if (marker == null) return;
    marker.onTap?.call();
  }

  void onLineTapped(mgl.Line line) {
    _lineToPolyline[line.id]?.onTap?.call();
  }

  // ── Diff helpers (called from widget on setState) ──────────

  Future<void> diffMarkers(
    Set<Marker> oldSet,
    Set<Marker> newSet,
  ) async {
    if (!_isStyleLoaded) return;
    final oldMap = {for (final m in oldSet) m.markerId: m};
    final newMap = {for (final m in newSet) m.markerId: m};

    // Remove deleted
    for (final id in oldMap.keys) {
      if (!newMap.containsKey(id)) await _removeMarker(id);
    }
    // Add new
    for (final entry in newMap.entries) {
      if (!oldMap.containsKey(entry.key)) {
        await addMarker(entry.value);
      } else if (oldMap[entry.key] != entry.value) {
        // Update changed (position, icon, etc.)
        await _updateMarker(entry.value);
      }
    }
  }

  Future<void> diffPolylines(
    Set<Polyline> oldSet,
    Set<Polyline> newSet,
  ) async {
    if (!_isStyleLoaded) return;
    final oldMap = {for (final p in oldSet) p.polylineId: p};
    final newMap = {for (final p in newSet) p.polylineId: p};

    for (final id in oldMap.keys) {
      if (!newMap.containsKey(id)) await _removePolyline(id);
    }
    for (final entry in newMap.entries) {
      if (!oldMap.containsKey(entry.key)) {
        await addPolyline(entry.value);
      } else if (oldMap[entry.key] != entry.value) {
        await _updatePolyline(entry.value);
      }
    }
  }

  Future<void> diffCircles(
    Set<Circle> oldSet,
    Set<Circle> newSet,
  ) async {
    if (!_isStyleLoaded) return;
    final oldMap = {for (final c in oldSet) c.circleId: c};
    final newMap = {for (final c in newSet) c.circleId: c};

    for (final id in oldMap.keys) {
      if (!newMap.containsKey(id)) await _removeCircle(id);
    }
    for (final entry in newMap.entries) {
      if (!oldMap.containsKey(entry.key)) {
        await addCircle(entry.value);
      } else if (oldMap[entry.key] != entry.value) {
        await _updateCircle(entry.value);
      }
    }
  }

  Future<void> diffPolygons(
    Set<Polygon> oldSet,
    Set<Polygon> newSet,
  ) async {
    if (!_isStyleLoaded) return;
    final oldMap = {for (final p in oldSet) p.polygonId: p};
    final newMap = {for (final p in newSet) p.polygonId: p};

    for (final id in oldMap.keys) {
      if (!newMap.containsKey(id)) await _removePolygon(id);
    }
    for (final entry in newMap.entries) {
      if (!oldMap.containsKey(entry.key)) {
        await addPolygon(entry.value);
      } else if (oldMap[entry.key] != entry.value) {
        await _updatePolygon(entry.value);
      }
    }
  }

  // ── Clear all ──────────────────────────────────────────────

  /// Removes every marker, polyline, circle, and polygon from the map.
  Future<void> clearOverlays() async {
    await _raw.clearSymbols();
    await _raw.clearLines();
    await _raw.clearCircles();
    await _raw.clearFills();
    _symbols.clear();
    _symbolToMarker.clear();
    _lines.clear();
    _lineToPolyline.clear();
    _circles.clear();
    _fills.clear();
  }

  // ── Siro API integrations ───────────────────────────────

  /// Searches for places using the Siro Geocoding API.
  Future<List<dynamic>> searchPlaces(String query) async {
    final uri = Uri.https('map-saas.intaleqapp.com', '/api/geocoding/search', {
      'q': query,
      'api_key': _apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Geocoding request failed: ${res.statusCode}');
  }

  /// Reverse geocodes a [LatLng] to a place description.
  Future<Map<String, dynamic>> reverseGeocode(mgl.LatLng position) async {
    final uri = Uri.https('map-saas.intaleqapp.com', '/api/geocoding/reverse', {
      'lat': position.latitude.toString(),
      'lng': position.longitude.toString(),
      'api_key': _apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Reverse geocoding failed: ${res.statusCode}');
  }

  /// Fetches a route between [origin] and [destination].
  ///
  /// [profile] is one of: `driving`, `cycling`, `walking`.
  /// [steps] when true, returns turn-by-turn navigation steps.
  /// Returns the raw Siro Routing API response.
  Future<Map<String, dynamic>> getDirections(
    mgl.LatLng origin,
    mgl.LatLng destination, {
    String profile = 'driving',
    bool steps = true,
  }) async {
    final uri = Uri.https('map-saas.intaleqapp.com', '/api/maps/route', {
      'fromLat': origin.latitude.toString(),
      'fromLng': origin.longitude.toString(),
      'toLat': destination.latitude.toString(),
      'toLng': destination.longitude.toString(),
      'profile': profile,
      'steps': steps.toString(),
      'api_key': _apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Routing request failed: ${res.statusCode}');
  }

  /// High-level helper to fetch and draw a route on the map.
  ///
  /// Returns the [PolylineId] of the drawn route, or null if it failed.
  Future<PolylineId?> drawRoute({
    required mgl.LatLng origin,
    required mgl.LatLng destination,
    String profile = 'driving',
    Color color = const Color(0xFF2196F3),
    double width = 5.0,
  }) async {
    try {
      final data = await getDirections(origin, destination, profile: profile);
      if (data['status'] == 'success' && data['data'] != null) {
        final List<dynamic> points = data['data']['points'];
        final List<mgl.LatLng> path = points
            .map((p) => mgl.LatLng(p['lat'] as double, p['lng'] as double))
            .toList();

        final polylineId =
            PolylineId('route_${DateTime.now().millisecondsSinceEpoch}');
        final polyline = Polyline(
          polylineId: polylineId,
          points: path,
          color: color,
          width: width,
        );

        await addPolyline(polyline);
        return polylineId;
      }
    } catch (e) {
      print('SiroMapController.drawRoute error: $e');
    }
    return null;
  }

  // ── Bitmap loader helper ───────────────────────────────────

  final Set<String> _loadedImages = {};

  Future<void> _loadBitmapIfNeeded(SiroBitmap bitmap) async {
    final id = bitmap.mapLibreImageId;
    if (_loadedImages.contains(id)) return;

    if (bitmap.bytes != null) {
      await _raw.addImage(id, bitmap.bytes!);
      _loadedImages.add(id);
      print("🖼️ [SiroMapController] Registered custom marker bitmap from bytes: $id");
    } else if (bitmap.assetName != null) {
      try {
        final data = await rootBundle.load(bitmap.assetName!);
        await _raw.addImage(id, data.buffer.asUint8List());
        _loadedImages.add(id);
        print("🖼️ [SiroMapController] Registered custom marker asset: ${bitmap.assetName} as $id");
      } catch (e) {
        print("⚠️ [SiroMapController] Failed to load asset image ${bitmap.assetName}: $e");
      }
    }
    // Style-registered images need no loading.
  }
}

/// Backward compatibility alias for developers migrating from `google_maps_flutter`.
typedef GoogleMapController = SiroMapController;


