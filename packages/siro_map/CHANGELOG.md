## Unreleased

* **Telemetry (Mandatory & Automatic):** Telemetry is now mandatory and enabled by default (`_enabled = true`).
  `SiroTelemetryService.initialize` makes `consentGranted` optional (defaults to `true`) and auto-generates
  or loads the `installId`.
* **Zero Boilerplate Widget Integration:** `SiroMap` widget automatically initializes `SiroTelemetryService`
  in `initState` using `apiKey`, running background telemetry seamlessly and invisibly.
* `SiroTelemetryService.loadOrCreateInstallId()` stores the random install ID in SharedPreferences.
  The package depends on `shared_preferences`.
* Telemetry: a stationary device records a heartbeat every 30 seconds from an internal
  timer, so the heartbeat no longer depends on new GPS events arriving.
* Telemetry: `SiroTelemetryService.isStationary` and `stationaryChanges` report the stationary
  state, so the host app can lower its GPS rate while the vehicle is stopped. No new dependencies.

## 2.3.0

* Refreshed bundled `assets/style.json` (offline fallback) to match the live server style:
  slate-on-sand road palette, per-class zoom thresholds (fixes low-zoom street clutter),
  building layer ordering fix (labels/icons no longer hidden under building fills),
  bridge rendering, seasonal/intermittent waterway styling, expanded POI categories
  (shop, bank, fuel, hotel, police), and OSM-Carto-style landuse tinting
  (retail/farmland/forest/grass/power).
* Removed the broken `demotiles.maplibre.org` sprite reference from the bundled style —
  apps must now supply POI icons via `onStyleLoaded` + `styleimagemissing` (see
  `apps/web/src/utils/mapIcons.ts` in the monorepo for the reference implementation).
  Without this, icon-based layers (POIs, direction arrows) render with empty icons.
* Note: this only updates the **local/offline** style asset. The primary runtime path
  (`SiroStyles.light/obsidian`) already served the corrected style live via
  `/api/maps/style.json` as of 2026-07-31 — no server change needed for those.

## 2.2.1

* Fixed Polyline and Marker comparison/equality checks.

## 2.2.0

* Added `onStyleLoaded` callback to `SiroMap` to handle style initialization.
* Improved overlay persistence: Markers, Polylines, Circles, and Polygons are now automatically restored after style changes (e.g., toggling Dark Mode).
* Exported MapLibre offline management primitives (`OfflineRegion`, `downloadOfflineRegion`, etc.) for advanced usage.
* Exported `MyLocationRenderMode` and `MyLocationTrackingMode` for location UI customization.
* Fixed `trackCameraPosition` logic to correctly trigger `onCameraIdle`.

## 2.1.3

* Fixed missing `dart:ui` import in `types.dart`.
* Verified compatibility with Flutter 3.22.

## 2.1.2

* Updated dependencies to latest stable versions (`http`, `lints`, `meta`).
* Fixed `onCameraMoveStarted` not being triggered correctly.
* Updated `README.md` to reflect the latest version.

## 2.1.1

* Finalized static analysis and documentation fixes for maximum pub.dev score.
* Renamed deprecated MapLibre components to latest naming conventions.
* Fixed deprecated Color member usage.

## 2.1.0

* Fixed static analysis warnings (unused imports and variables).
* Added comprehensive documentation for core SDK elements.
* Improved API parity with Google Maps Flutter (CameraPosition helpers).
* Added an `example/` project demonstrating SDK integration.

## 2.0.0

**Breaking redesign — full Google Maps Flutter API parity.**

* Replaced imperative `add/removeMarker()` controller methods with a
  **declarative `Set<Marker>` / `Set<Polyline>` / `Set<Circle>` / `Set<Polygon>`**
  API on the widget, identical to `google_maps_flutter`.
* Added `MarkerId`, `PolylineId`, `CircleId`, `PolygonId` typed ID classes.
* Added per-object callbacks: `Marker.onTap`, `Marker.onDragEnd`, `Polyline.onTap`, etc.
* Added `SiroBitmap` (mirrors `BitmapDescriptor`): `defaultMarker`,
  `defaultMarkerWithHue`, `fromAsset`, `fromBytes`, `fromStyleImage`.
* Added `InfoWindow` model with `title`, `snippet`, and `onTap`.
* Added `SiroMapType` enum (`normal`, `light`, `satellite`, `none`).
* Added `MinMaxZoomPreference` and `CameraTargetBounds`.
* Renamed `getRoute()` → `getDirections()` for API clarity.
* Added `reverseGeocode()` to controller.
* Added `PolylineUtils.encode()` and `PolylineUtils.totalLength()`.
* Added `SiroColors` Flutter `Color` constants alongside hex strings.
* Removed `geolocator` and `get`/`latlong2` dependencies (no longer needed).

## 1.0.0

* Initial release. Imperative add/remove API over MapLibre GL.