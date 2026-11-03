import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'package:webview_flutter/webview_flutter.dart';

/// وحدة التحكم التفاعلية بمحرك التضاريس ثلاثية الأبعاد السيادي
class Siro3DController {
  final WebViewController _webController;

  Siro3DController(this._webController);

  /// تحديث موقع المركبة وزاويتها وتحريك كاميرا التضاريس 3D برؤية السائق (Cockpit) مع ارتفاعات الطريق
  Future<void> updateUserLocation({
    required double lng,
    required double lat,
    required double heading,
    bool followCamera = true,
    double pitch = 68.0,
    double zoom = 18.5,
  }) async {
    try {
      final script =
          "if (window.updateUserLocation) { window.updateUserLocation($lng, $lat, $heading, $followCamera, $pitch, $zoom); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// رسم مسار الملاحة ثلاثي الأبعاد فوق تضاريس الجبال والمنحدرات
  Future<void> setRoute(List<mgl.LatLng> points) async {
    try {
      final coords = points.map((p) => [p.longitude, p.latitude]).toList();
      final jsonStr = jsonEncode(coords);
      final script = "if (window.setRouteGeoJson) { window.setRouteGeoJson($jsonStr); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// مسح مسار الملاحة
  Future<void> clearRoute() async {
    try {
      const script = "if (window.clearRoute) { window.clearRoute(); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// تحديد نقطة الوجهة النهائية على التضاريس والطيران السلس نحوها
  Future<void> setDestination(mgl.LatLng? dest, {bool flyTo = false}) async {
    try {
      if (dest == null) {
        await _webController.runJavaScript("if (window.clearDestination) { window.clearDestination(); }");
      } else {
        final script =
            "if (window.setDestination) { window.setDestination(${dest.longitude}, ${dest.latitude}); }" +
            (flyTo ? " if (window.flyToDestination) { window.flyToDestination(${dest.longitude}, ${dest.latitude}); }" : "");
        await _webController.runJavaScript(script);
      }
    } catch (_) {}
  }

  /// تغيير معامل تضخيم وبروز الجبال والوديان (1.0x إلى 3.5x)
  Future<void> setTerrainExaggeration(double factor) async {
    try {
      final script = "if (window.setTerrainExaggeration) { window.setTerrainExaggeration($factor); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// إمالة زاوية الكاميرا نحو الأفق (0° إلى 85°)
  Future<void> setPitch(double pitch) async {
    try {
      final script = "if (window.setCameraPitch) { window.setCameraPitch($pitch); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// تدوير زاوية البوصلة للكاميرا (0° إلى 360°)
  Future<void> setBearing(double bearing) async {
    try {
      final script = "if (window.setCameraBearing) { window.setCameraBearing($bearing); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// الطيران السلس المجسم نحو موقع جغرافي ومعلم محدد
  Future<void> flyTo(
    mgl.LatLng target, {
    double zoom = 18.5,
    double pitch = 68.0,
    double bearing = 0.0,
  }) async {
    try {
      final script =
          "if (window.flyToLocation) { window.flyToLocation(${target.longitude}, ${target.latitude}, $zoom, $pitch, $bearing); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// بدء الدوران السينمائي 360° حول التضاريس والقمم الجبلية
  Future<void> startOrbit({double speed = 1.0}) async {
    try {
      final script = "if (window.startOrbit) { window.startOrbit($speed); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// إيقاف الدوران السينمائي
  Future<void> stopOrbit() async {
    try {
      final script = "if (window.stopOrbit) { window.stopOrbit(); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// محاكاة زاوية سقوط أشعة الشمس والظلال الفلكية على الجبال
  Future<void> setSunLighting(int minutes) async {
    try {
      final script = "if (window.setSunLighting) { window.setSunLighting($minutes); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// إظهار أو إخفاء خطوط الكنتور الطبوغرافية
  Future<void> toggleContours(bool visible) async {
    try {
      final script = "if (window.toggleContours) { window.toggleContours($visible); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// إظهار أو إخفاء المباني والمنشآت المعمارية ثلاثية الأبعاد
  Future<void> toggleBuildings(bool visible) async {
    try {
      final script = "if (window.toggleBuildings) { window.toggleBuildings($visible); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }

  /// تغيير نمط الخريطة
  Future<void> setStyle(String styleUrl) async {
    try {
      final script = "if (window.changeMapStyle) { window.changeMapStyle('$styleUrl'); }";
      await _webController.runJavaScript(script);
    } catch (_) {}
  }
}

/// خريطة التضاريس ثلاثية الأبعاد السيادية المسرّعة عتادياً بتقنية GPU Mesh
class Siro3DMap extends StatefulWidget {
  final mgl.LatLng initialCenter;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final double terrainExaggeration;
  final bool enableSunSimulation;
  final int sunTimeMinutes;
  final bool showContours;
  final bool showBuildings;
  final String? customStyleUrl;
  final mgl.LatLng? userLocation;
  final double userHeading;
  final bool followUser;
  final List<mgl.LatLng>? routePoints;
  final mgl.LatLng? destination;
  final Function(Siro3DController)? onMapCreated;
  final Function(mgl.LatLng)? onTap;
  final Function(mgl.LatLng)? onLongPress;
  final Function(double)? onElevationChanged;

  const Siro3DMap({
    super.key,
    this.initialCenter = const mgl.LatLng(31.9539, 35.9106),
    this.initialZoom = 18.5,
    this.initialPitch = 68.0,
    this.initialBearing = 0.0,
    this.terrainExaggeration = 2.0,
    this.enableSunSimulation = true,
    this.sunTimeMinutes = 1110,
    this.showContours = true,
    this.showBuildings = false, // Turned OFF by default so roads & terrain are unobstructed
    this.customStyleUrl,
    this.userLocation,
    this.userHeading = 0.0,
    this.followUser = true,
    this.routePoints,
    this.destination,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onElevationChanged,
  });

  @override
  State<Siro3DMap> createState() => _Siro3DMapState();
}

class _Siro3DMapState extends State<Siro3DMap> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Siro3DController? _siroController;
  Siro3DController? get controller => _siroController;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void didUpdateWidget(Siro3DMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = _siroController;
    if (ctrl == null) return;

    if (widget.userLocation != null &&
        (widget.userLocation != oldWidget.userLocation ||
            widget.userHeading != oldWidget.userHeading ||
            widget.followUser != oldWidget.followUser)) {
      ctrl.updateUserLocation(
        lng: widget.userLocation!.longitude,
        lat: widget.userLocation!.latitude,
        heading: widget.userHeading,
        followCamera: widget.followUser,
        pitch: widget.initialPitch,
        zoom: widget.initialZoom,
      );
    }

    if (widget.routePoints != oldWidget.routePoints) {
      if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
        ctrl.setRoute(widget.routePoints!);
      } else {
        ctrl.clearRoute();
      }
    }

    if (widget.destination != oldWidget.destination) {
      ctrl.setDestination(widget.destination);
    }

    if (widget.terrainExaggeration != oldWidget.terrainExaggeration) {
      ctrl.setTerrainExaggeration(widget.terrainExaggeration);
    }
  }

  void _initEngine() {
    final center = widget.userLocation ?? widget.initialCenter;
    final initialLng = center.longitude;
    final initialLat = center.latitude;
    final styleUri = widget.customStyleUrl ??
        'https://map-saas.intaleqapp.com/style-3d-terrain.json';

    final routeJson = widget.routePoints != null
        ? jsonEncode(
            widget.routePoints!.map((p) => [p.longitude, p.latitude]).toList())
        : '[]';

    final destJson = widget.destination != null
        ? jsonEncode(
            [widget.destination!.longitude, widget.destination!.latitude])
        : 'null';

    final htmlContent = _generateEngineHtml(
      lng: initialLng,
      lat: initialLat,
      heading: widget.userHeading,
      zoom: widget.initialZoom,
      pitch: widget.initialPitch,
      bearing: widget.initialBearing,
      exaggeration: widget.terrainExaggeration,
      styleUrl: styleUri,
      routeJson: routeJson,
      destJson: destJson,
      showContours: widget.showContours,
      showBuildings: widget.showBuildings,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..addJavaScriptChannel(
        'Siro3DBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            final event = data['event'] as String?;
            print("🛰️ [Siro3DBridge] Event received: $event");
            if (event == 'mapLoaded') {
              print("✅ [Siro3DMap] 3D Terrain Map successfully loaded with GPU DEM mesh!");
              setState(() => _isLoading = false);
              final ctrl = Siro3DController(_controller);
              _siroController = ctrl;
              widget.onMapCreated?.call(ctrl);

              if (widget.userLocation != null) {
                ctrl.updateUserLocation(
                  lng: widget.userLocation!.longitude,
                  lat: widget.userLocation!.latitude,
                  heading: widget.userHeading,
                  followCamera: widget.followUser,
                  pitch: widget.initialPitch,
                  zoom: widget.initialZoom,
                );
              }
              if (widget.routePoints != null &&
                  widget.routePoints!.isNotEmpty) {
                ctrl.setRoute(widget.routePoints!);
              }
              if (widget.destination != null) {
                ctrl.setDestination(widget.destination);
              }
            } else if (event == 'mapClick') {
              final lat = (data['lat'] as num).toDouble();
              final lng = (data['lng'] as num).toDouble();
              widget.onTap?.call(mgl.LatLng(lat, lng));
            } else if (event == 'mapLongPress') {
              final lat = (data['lat'] as num).toDouble();
              final lng = (data['lng'] as num).toDouble();
              widget.onLongPress?.call(mgl.LatLng(lat, lng));
            } else if (event == 'elevationUpdate') {
              final elev = (data['altitude'] as num).toDouble();
              widget.onElevationChanged?.call(elev);
            } else if (event == 'mapError' || event == 'jsError') {
              print("❌ [Siro3DMap] $event: ${data['message']}");
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            print("🚀 [Siro3DMap] onPageFinished: $url");
            setState(() => _isLoading = false);
            final ctrl = Siro3DController(_controller);
            _siroController = ctrl;
            widget.onMapCreated?.call(ctrl);
          },
          onWebResourceError: (error) {
            print("⚠️ [Siro3DMap] WebResourceError: ${error.description} (code: ${error.errorCode})");
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://map-saas.intaleqapp.com/');
  }

  String _generateEngineHtml({
    required double lng,
    required double lat,
    required double heading,
    required double zoom,
    required double pitch,
    required double bearing,
    required double exaggeration,
    required String styleUrl,
    required String routeJson,
    required String destJson,
    required bool showContours,
    required bool showBuildings,
  }) {
    return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>Siro Sovereign 3D Terrain Engine</title>
  <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" crossorigin="anonymous" />
  <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js" crossorigin="anonymous"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; overflow: hidden; background: #0f172a; }
    .maplibregl-ctrl-bottom-left, .maplibregl-ctrl-bottom-right { display: none !important; }
    
    /* High-Visibility Sovereign Vehicle Marker matching Web Consumer Map */
    .route-car-container {
      position: relative;
      width: 56px;
      height: 56px;
      display: flex;
      align-items: center;
      justify-content: center;
      pointer-events: none;
      z-index: 99999;
    }
    .route-car-rotator {
      position: relative;
      width: 56px;
      height: 56px;
      display: flex;
      align-items: center;
      justify-content: center;
      transform-origin: center center;
      transition: transform 0.12s linear;
    }

    /* Sovereign 3D Destination Pin */
    .dest-marker-container {
      width: 44px;
      height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
      pointer-events: none;
      filter: drop-shadow(0 6px 14px rgba(239, 68, 68, 0.8));
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    let isOrbiting = false;
    let orbitAnimId = null;
    let userMarker = null;
    let destMarker = null;
    let smoothBearing = null;
    let lastElevationPost = 0;
    const initialRoute = $routeJson;
    const initialDest = $destJson;

    const map = new maplibregl.Map({
      container: 'map',
      style: '$styleUrl',
      center: [$lng, $lat],
      zoom: $zoom,
      pitch: $pitch,
      bearing: $bearing,
      maxPitch: 85,
      canvasContextAttributes: { antialias: true, preserveDrawingBuffer: false }
    });

    function smoothAngle(current, target, factor) {
      let diff = (target - current) % 360;
      if (diff < -180) diff += 360;
      if (diff > 180) diff -= 360;
      return current + diff * factor;
    }

    function createCarElement() {
      const container = document.createElement('div');
      container.className = 'route-car-container';
      container.innerHTML = `
        <div class="route-car-rotator">
          <!-- Underglow Pulse Ring -->
          <div style="position:absolute; width:48px; height:48px; border-radius:50%; background:radial-gradient(circle, rgba(200,248,122,0.7) 0%, rgba(200,248,122,0.2) 60%, transparent 80%); filter:blur(4px); pointer-events:none;"></div>
          <!-- Forward LED Headlight Beams projecting forward onto the road -->
          <div style="position:absolute; top:-56px; left:50%; transform:translateX(-50%); width:86px; height:70px; background:radial-gradient(ellipse at 50% 100%, rgba(200,248,122,0.95) 0%, rgba(200,248,122,0.35) 55%, transparent 80%); pointer-events:none; filter:blur(3px);"></div>
          <!-- Sovereign 3D Sports Vehicle SVG -->
          <svg width="34" height="52" viewBox="0 0 34 52" fill="none" xmlns="http://www.w3.org/2000/svg" style="filter: drop-shadow(0 10px 18px rgba(0,0,0,0.95)) drop-shadow(0 0 12px rgba(200,248,122,0.85));">
            <rect x="3" y="4" width="28" height="44" rx="9" fill="#111812" stroke="#c8f87a" stroke-width="2.4"/>
            <path d="M5 14C5 8 9 5 17 5C25 5 29 8 29 14V17H5V14Z" fill="#1b2a1f"/>
            <circle cx="8" cy="7" r="2.8" fill="#c8f87a"/>
            <circle cx="26" cy="7" r="2.8" fill="#c8f87a"/>
            <path d="M7 18L10 24H24L27 18C27 18 22 17 17 17C12 17 7 18 7 18Z" fill="#38e892" opacity="0.95"/>
            <rect x="8" y="24" width="18" height="12" rx="3.5" fill="#0c140d"/>
            <path d="M9 37L10 41H24L25 37H9Z" fill="#2d3f32"/>
            <rect x="6" y="45" width="22" height="3" rx="1.5" fill="#ef4444"/>
            <rect x="9" y="45.5" width="16" height="2" rx="1" fill="#fecaca"/>
            <rect x="0" y="16" width="3" height="5" rx="1.5" fill="#c8f87a"/>
            <rect x="31" y="16" width="3" height="5" rx="1.5" fill="#c8f87a"/>
          </svg>
        </div>`;
      return container;
    }

    function createDestElement() {
      const container = document.createElement('div');
      container.className = 'dest-marker-container';
      container.innerHTML = `
        <svg width="42" height="42" viewBox="0 0 42 42" fill="none">
          <circle cx="21" cy="21" r="18" fill="#EF4444" fill-opacity="0.25"/>
          <circle cx="21" cy="21" r="13" fill="#EF4444" stroke="#FFFFFF" stroke-width="2.5"/>
          <path d="M17 13V29M17 14H27L23.5 19L27 24H17" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`;
      return container;
    }

    window.onerror = function(msg, url, line) {
      if (msg && msg.indexOf('Script error') !== -1) return;
      if (window.Siro3DBridge) {
        window.Siro3DBridge.postMessage(JSON.stringify({ event: 'jsError', message: msg + ' (' + line + ')' }));
      }
    };

    map.on('error', function(e) {
      if (window.Siro3DBridge) {
        const errMsg = (e && e.error && e.error.message) ? e.error.message : ((e && e.message) ? e.message : '');
        if (errMsg && !errMsg.includes('Load failed') && !errMsg.includes('404')) {
          window.Siro3DBridge.postMessage(JSON.stringify({ event: 'mapError', message: errMsg }));
        }
      }
    });

    map.on('load', () => {
      // 1. Ensure terrain-dem raster elevation source exists
      if (!map.getSource('terrain-dem')) {
        map.addSource('terrain-dem', {
          type: 'raster-dem',
          tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
          encoding: 'terrarium',
          tileSize: 256,
          maxzoom: 15
        });
      }

      // 2. Set true GPU Vertex Terrain Mesh Displacement with exact 2.0x exaggeration
      map.setTerrain({ source: 'terrain-dem', exaggeration: $exaggeration });

      // 3. User Vehicle Marker pinned to 3D terrain
      userMarker = new maplibregl.Marker({
        element: createCarElement(),
        rotationAlignment: 'map',
        pitchAlignment: 'map'
      }).setLngLat([$lng, $lat]).addTo(map);

      // 4. Route Source and 3D draping layers
      map.addSource('route-3d-src', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: initialRoute.length ? initialRoute : []
          }
        }
      });

      map.addLayer({
        id: 'route-3d-casing',
        type: 'line',
        source: 'route-3d-src',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': '#0F172A',
          'line-width': 10,
          'line-opacity': 0.85
        }
      });

      map.addLayer({
        id: 'route-3d-core',
        type: 'line',
        source: 'route-3d-src',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': '#38BDF8',
          'line-width': 5.5
        }
      });

      // 5. Destination Marker
      if (initialDest && Array.isArray(initialDest) && initialDest.length === 2) {
        destMarker = new maplibregl.Marker({
          element: createDestElement(),
          rotationAlignment: 'viewport',
          pitchAlignment: 'viewport'
        }).setLngLat(initialDest).addTo(map);
      }

      // 6. Ensure 3D extruded buildings that block roads and vision are completely hidden
      const buildingLayers = ['3d-buildings-extrusion', '3d-buildings-ground-shadows', 'building-3d', 'building-3d-osm'];
      for (let i = 0; i < buildingLayers.length; i++) {
        if (map.getLayer(buildingLayers[i])) {
          map.setLayoutProperty(buildingLayers[i], 'visibility', 'none');
        }
      }

      // 7. Setup Long-Press Touch Gesture on the Map Canvas
      setupLongPressListener();

      // Notify Flutter host
      if (window.Siro3DBridge) {
        window.Siro3DBridge.postMessage(JSON.stringify({ event: 'mapLoaded' }));
      }
    });

    map.on('click', (e) => {
      if (window.Siro3DBridge) {
        window.Siro3DBridge.postMessage(JSON.stringify({
          event: 'mapClick',
          lat: e.lngLat.lat,
          lng: e.lngLat.lng
        }));
      }
    });

    function setupLongPressListener() {
      const canvas = map.getCanvas();
      let touchStartPos = null;
      let longPressTimer = null;
      let isMoved = false;
      let longPressTriggered = false;

      canvas.addEventListener('touchstart', (e) => {
        if (e.touches.length === 1) {
          isMoved = false;
          longPressTriggered = false;
          touchStartPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
          longPressTimer = setTimeout(() => {
            if (!isMoved && touchStartPos && !longPressTriggered) {
              longPressTriggered = true;
              const rect = canvas.getBoundingClientRect();
              const point = [touchStartPos.x - rect.left, touchStartPos.y - rect.top];
              const lngLat = map.unproject(point);

              // Instantly show destination pin and fly smoothly to it
              window.setDestination(lngLat.lng, lngLat.lat);
              window.flyToDestination(lngLat.lng, lngLat.lat);

              if (window.Siro3DBridge) {
                window.Siro3DBridge.postMessage(JSON.stringify({
                  event: 'mapLongPress',
                  lat: lngLat.lat,
                  lng: lngLat.lng
                }));
              }
            }
          }, 500);
        }
      }, { passive: true });

      canvas.addEventListener('touchmove', (e) => {
        if (touchStartPos && e.touches.length === 1) {
          const dx = Math.abs(e.touches[0].clientX - touchStartPos.x);
          const dy = Math.abs(e.touches[0].clientY - touchStartPos.y);
          if (dx > 10 || dy > 10) {
            isMoved = true;
            clearTimeout(longPressTimer);
            longPressTimer = null;
          }
        }
      }, { passive: true });

      canvas.addEventListener('touchend', () => {
        clearTimeout(longPressTimer);
        longPressTimer = null;
      }, { passive: true });

      // Simulator & Desktop contextmenu support
      map.on('contextmenu', (e) => {
        if (longPressTriggered) return;
        longPressTriggered = true;
        window.setDestination(e.lngLat.lng, e.lngLat.lat);
        window.flyToDestination(e.lngLat.lng, e.lngLat.lat);
        if (window.Siro3DBridge) {
          window.Siro3DBridge.postMessage(JSON.stringify({
            event: 'mapLongPress',
            lat: e.lngLat.lat,
            lng: e.lngLat.lng
          }));
        }
      });
    }

    // ── Global JS Bridge Exposed to Flutter ──
    window.updateUserLocation = function(lng, lat, heading, followCamera, pitch, zoom) {
      if (!map) return;

      const rawHeading = heading || 0;
      if (smoothBearing === null) {
        smoothBearing = rawHeading;
      } else {
        smoothBearing = smoothAngle(smoothBearing, rawHeading, 0.35);
      }
      const cameraBearing = smoothBearing;

      if (userMarker) {
        userMarker.setLngLat([lng, lat]);
        const rotator = userMarker.getElement().querySelector('.route-car-rotator');
        if (rotator) {
          const screenBearing = rawHeading - map.getBearing();
          rotator.style.transform = 'rotate(' + screenBearing + 'deg)';
        }
      }

      if (followCamera) {
        // Driver Eye-Level Cockpit View:
        // Positioned 3.5m ahead of vehicle, locked 68° pitch, close 18.5 zoom looking ahead through windshield
        const rad = (cameraBearing * Math.PI) / 180;
        const aheadMetersCockpit = 3.5;
        const aheadLat = lat + (aheadMetersCockpit * Math.cos(rad)) / 111320;
        const aheadLng = lng + (aheadMetersCockpit * Math.sin(rad)) / (111320 * Math.cos((lat * Math.PI) / 180));

        map.easeTo({
          center: [aheadLng, aheadLat],
          zoom: zoom || 18.5,
          bearing: cameraBearing,
          pitch: pitch || 68.0,
          duration: 200,
          easing: function(t) { return t; }
        });
      }

      try {
        const now = Date.now();
        if (now - lastElevationPost > 400) {
          lastElevationPost = now;
          const elev = map.queryTerrainElevation([lng, lat]);
          if (elev !== null && elev !== undefined && window.Siro3DBridge) {
            window.Siro3DBridge.postMessage(JSON.stringify({
              event: 'elevationUpdate',
              altitude: elev
            }));
          }
        }
      } catch (_) {}
    };

    window.flyToDestination = function(lng, lat) {
      if (!map) return;
      map.flyTo({
        center: [lng, lat],
        zoom: 17.5,
        pitch: 66,
        essential: true,
        duration: 1600
      });
    };

    window.setRouteGeoJson = function(coords) {
      if (!map) return;
      const src = map.getSource('route-3d-src');
      if (src && coords) {
        src.setData({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: coords }
        });
      }
    };

    window.clearRoute = function() {
      if (!map) return;
      const src = map.getSource('route-3d-src');
      if (src) {
        src.setData({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: [] }
        });
      }
    };

    window.setDestination = function(lng, lat) {
      if (!map) return;
      if (!destMarker) {
        destMarker = new maplibregl.Marker({
          element: createDestElement(),
          rotationAlignment: 'viewport',
          pitchAlignment: 'viewport'
        }).addTo(map);
      }
      destMarker.setLngLat([lng, lat]);
    };

    window.clearDestination = function() {
      if (destMarker) {
        destMarker.remove();
        destMarker = null;
      }
    };

    window.setTerrainExaggeration = function(factor) {
      if (map && map.getSource('terrain-dem')) {
        map.setTerrain({ source: 'terrain-dem', exaggeration: factor });
      }
    };

    window.setCameraPitch = function(p) {
      if (map) map.setPitch(p);
    };

    window.setCameraBearing = function(b) {
      if (map) map.setBearing(b);
    };

    window.flyToLocation = function(lng, lat, zoom, pitch, bearing) {
      if (map) {
        map.flyTo({
          center: [lng, lat],
          zoom: zoom || 18.5,
          pitch: pitch || 68,
          bearing: bearing || 0,
          essential: true,
          duration: 1800
        });
      }
    };

    window.startOrbit = function(speed) {
      isOrbiting = true;
      const step = 0.25 * (speed || 1.0);
      function orbit() {
        if (!isOrbiting) return;
        currentBearing = (map.getBearing() + step) % 360;
        map.setBearing(currentBearing);
        orbitAnimId = requestAnimationFrame(orbit);
      }
      cancelAnimationFrame(orbitAnimId);
      orbit();
    };

    window.stopOrbit = function() {
      isOrbiting = false;
      if (orbitAnimId) cancelAnimationFrame(orbitAnimId);
    };

    window.setSunLighting = function(minutes) {
      const fraction = Math.max(0, Math.min(1, (minutes - 330) / (1260 - 330)));
      const sunAzimuth = 75.0 + (fraction * 215.0);
      if (map && map.getLayer('terrain-3d-hillshading')) {
        map.setPaintProperty('terrain-3d-hillshading', 'hillshade-illumination-direction', sunAzimuth % 360);
      }
    };

    window.toggleContours = function(visible) {
      if (map && map.getLayer('tactical-contour-minor')) {
        map.setLayoutProperty('tactical-contour-minor', 'visibility', visible ? 'visible' : 'none');
      }
      if (map && map.getLayer('tactical-contour-major')) {
        map.setLayoutProperty('tactical-contour-major', 'visibility', visible ? 'visible' : 'none');
      }
    };

    window.toggleBuildings = function(visible) {
      // Kept disabled for unobstructed navigation & driving
    };

    window.changeMapStyle = function(url) {
      if (map) {
        map.setStyle(url);
        map.once('style.load', () => {
          if (!map.getSource('terrain-dem')) {
            map.addSource('terrain-dem', {
              type: 'raster-dem',
              tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
              encoding: 'terrarium',
              tileSize: 256,
              maxzoom: 15
            });
          }
          map.setTerrain({ source: 'terrain-dem', exaggeration: $exaggeration });
        });
      }
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFEA580C)),
                  SizedBox(height: 14),
                  Text(
                    'تهيئة محرك التضاريس ثلاثية الأبعاد (GPU 3D Mesh)...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
