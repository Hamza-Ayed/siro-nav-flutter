# Siro Maps SDK for Flutter (`siro_map`)

A high-performance **drop-in replacement for `google_maps_flutter`** backed by MapLibre GL, optimized for Jordan, Syria, Saudi Arabia, UAE, and the broader MENA region.

---

## Why Siro Maps?

| Feature | `google_maps_flutter` | `siro_map` |
|---|---|---|
| Works in Syria & restricted zones | ❌ | ✅ |
| Self-hosted sovereign tiles | ❌ | ✅ |
| MENA-optimised data & Arabic search | ❌ | ✅ |
| 1:1 Google Maps Flutter API Parity | — | ✅ |
| Offline-ready 3D Terrain & Extrusions | ❌ | ✅ |

---

## Installation

```yaml
dependencies:
  siro_map: ^1.0.0
```

---

## Migration from `google_maps_flutter`

The API is intentionally 1:1 identical. Most migrations only need changing the import:

```dart
// Before:
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// After:
import 'package:siro_map/siro_map.dart';
```

| Google Maps | Siro Maps (`siro_map`) | Google-named alias kept for migration |
|---|---|---|
| `GoogleMap(…)` | `SiroMap(apiKey: key, …)` | `GoogleMap` |
| `GoogleMapController` | `SiroMapController` | `GoogleMapController` |
| `BitmapDescriptor` | `SiroBitmap` | `BitmapDescriptor` |
| `MapType.normal` | `SiroMapType.normal` | `MapType` |

Everything else — `Marker`, `Polyline`, `Circle`, `Polygon`, `MarkerId`, `PolylineId`, `InfoWindow`, `CameraUpdate`, `LatLng`, `LatLngBounds` — is **100% identical**.

---

## Usage

### Basic map

```dart
import 'package:siro_map/siro_map.dart';

SiroMap(
  apiKey: 'YOUR_SIRO_API_KEY',
  initialCameraPosition: CameraPosition(
    target: LatLng(31.9539, 35.9106), // Amman
    zoom: 14,
  ),
  onMapCreated: (SiroMapController controller) {
    _controller = controller;
  },
)
```

### Declarative markers (exactly like Google Maps Flutter)

```dart
// In your State:
Set<Marker> _markers = {};

// Add a marker — just setState:
setState(() {
  _markers = {
    Marker(
      markerId: MarkerId('driver_1'),
      position: LatLng(33.5138, 36.2765),
      icon: SiroBitmap.fromAsset('assets/icons/car.png'),
      infoWindow: InfoWindow(
        title: 'Ahmad',
        snippet: 'Toyota Corolla · 3 min away',
      ),
      onTap: () => print('driver tapped'),
    ),
  };
});

// Pass to widget:
SiroMap(
  apiKey: _apiKey,
  initialCameraPosition: _camera,
  markers: _markers,       // ← declarative
  polylines: _polylines,   // ← declarative
  circles: _circles,       // ← declarative
  polygons: _polygons,     // ← declarative
)
```

### Camera control

```dart
// Animate to a position
_controller.animateCamera(
  CameraUpdate.newLatLngZoom(LatLng(33.5, 36.2), 15),
);

// Fit bounds
_controller.animateCamera(
  CameraUpdate.newLatLngBounds(bounds, left: 50, right: 50, top: 100, bottom: 100),
);
```

### Get a route

```dart
final route = await _controller.getDirections(
  LatLng(33.5138, 36.2765),
  LatLng(33.49, 36.30),
  profile: 'driving',
);

// Decode the encoded polyline from the response
final points = PolylineUtils.decode(route['geometry']);

setState(() {
  _polylines = {
    Polyline(
      polylineId: PolylineId('route'),
      points: points,
      color: SiroColors.routeCyan,
      width: 5,
    ),
  };
});
```

### Search for places

```dart
final results = await _controller.searchPlaces('مطار دمشق');
```

### Map types

```dart
SiroMap(
  mapType: SiroMapType.normal,    // Dark Obsidian (default)
  // mapType: SiroMapType.light,
  // mapType: SiroMapType.satellite,
  ...
)
```

---

## API Reference

### `SiroMap` widget

| Property | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | required | Your Siro Maps API key |
| `initialCameraPosition` | `CameraPosition` | required | Starting camera |
| `markers` | `Set<Marker>` | `{}` | Declarative marker set |
| `polylines` | `Set<Polyline>` | `{}` | Declarative polyline set |
| `circles` | `Set<Circle>` | `{}` | Declarative circle set |
| `polygons` | `Set<Polygon>` | `{}` | Declarative polygon set |
| `onMapCreated` | `MapCreatedCallback?` | — | Fires once map is ready |
| `onStyleLoaded` | `VoidCallback?` | — | Style fully loaded & ready for overlays |
| `onTap` | `ArgumentCallback<LatLng>?` | — | Map tap |
| `onLongPress` | `ArgumentCallback<LatLng>?` | — | Map long press |
| `onCameraMove` | `CameraPositionCallback?` | — | Camera movement |
| `mapType` | `SiroMapType` | `.normal` | Tile style |
| `myLocationEnabled` | `bool` | `false` | Show user location dot |

### `SiroMapController`

| Method | Description |
|---|---|
| `animateCamera(update)` | Animated camera move |
| `moveCamera(update)` | Instant camera move |
| `getZoomLevel()` | Current zoom level |
| `getVisibleRegion()` | Current `LatLngBounds` |
| `clearOverlays()` | Remove all markers/lines/circles/polygons |
| `getDirections(origin, dest)` | Siro Routing API |
| `searchPlaces(query)` | Siro Geocoding API |
| `reverseGeocode(position)` | Reverse geocoding |
| `addImage(id, bytes)` | Register custom marker image |

---

## 🌐 Official Portals & Support

- **Developer Dashboard**: [https://map-dashboard.intaleqapp.com](https://map-dashboard.intaleqapp.com)
- **Live Vector Map**: [https://map.intaleqapp.com](https://map.intaleqapp.com)
- **Support & Inquiries**: `support@intaleqapp.com`

---

## License

MIT — see [LICENSE](LICENSE).