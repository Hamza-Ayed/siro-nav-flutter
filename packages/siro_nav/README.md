# siro_nav

Turn-by-turn navigation for Flutter, on Siro Maps. The route comes from the
Siro Maps API, the guidance is spoken in Arabic from bundled clips, and the
map is the Siro style. Your app stays in control: no external map app opens.

## Install

```yaml
dependencies:
  siro_nav:
    path: ../siro_nav # or your git / pub source
```

## Quick start

```dart
final nav = await SiroNavController.create(
  config: NavConfig(apiKey: 'YOUR_SIRO_API_KEY'),
);

final started = await nav.startNavigation(
  origin: NavPoint.fromLatLng(31.9539, 35.9106),
  destination: NavPoint.fromLatLng(31.9735, 35.9235),
);
if (!started) {
  debugPrint(nav.activeError.value); // Arabic text, safe to show the driver
}

// In your widget tree, once the trip has started:
SiroNavView(
  controller: nav,
  onExit: () => Navigator.of(context).pop(),
);
```

Dispose the controller when your screen is gone: `await nav.dispose();`

## Testing without driving

Pass `simulate: true` to drive the route at a fixed speed instead of using GPS:

```dart
await nav.startNavigation(
  origin: from,
  destination: to,
  simulate: true,
  simulationSpeedKmh: 70,
);
```

## What you get

| Member | Purpose |
|---|---|
| `SiroNavController.create({config})` | Controller with the bundled Arabic voice |
| `startNavigation({origin, destination, waypoints, simulate, simulationSpeedKmh})` | Fetches the route and starts guidance. Returns `false` and sets `activeError` on failure |
| `stopNavigation()` | Ends the trip and releases GPS |
| `isNavigating`, `route`, `currentInstruction`, `currentProgress`, `currentSpeedKmh`, `upcomingCamera`, `isOverspeeding`, `activeError` | Reactive state (`ValueListenable`) for your UI |
| `events` | Raw `NavEvent` stream from the engine |
| `setVoiceMuted(bool)`, `isVoiceMuted`, `voiceEngine` | Voice control |
| `SiroNavView({controller, onExit, styleUrl, vehicleScale, cameraZoom, cameraTilt})` | Full-screen map, route, vehicle, follow camera and HUD |
| `NavRouteSimulator` | A location source that drives a `NavRoute` at a set speed |
| `NavRouteException.code` | `ERR_UNAUTHORIZED_API_KEY`, `ERR_OUT_OF_COVERAGE`, `ERR_ROUTE_TIMEOUT`, `ERR_NETWORK`, `ERR_ROUTE_FAILED`, `ERR_NO_ROUTE`, `ERR_BAD_RESPONSE` |

## Notes

- **API key.** The SDK checks only that the key is present and has no spaces.
  The server decides whether it is valid, and rejects revoked or exhausted keys
  with HTTP 401/403, which the controller reports in `activeError`.
- **Endpoint.** Routes come from `NavConfig.baseUrl` (default
  `https://map-saas.intaleqapp.com/api`) at `/maps/route`. Override it for staging.
- **Map style.** `SiroNavView` uses the Siro Limestone day style by default.
  Pass a versioned `styleUrl` (for example `?v=…`) after a style release, so
  the CDN cache does not serve the old one.
- **Voice.** The Arabic clips are bundled as package assets. They are copied
  to the temp directory once and played as device files, which iOS requires.
- **Real GPS.** Requires location permission. Background location is off by
  default on iOS, so guidance pauses when the app is in the background.
- **One GPS stream per app (important).** On iOS, `geolocator` shares a single
  position stream between all listeners, with the settings of whoever
  subscribed first. If your app keeps its own `Geolocator.getPositionStream`
  open (for a home map, for example), cancel it while a trip runs and restart
  it afterwards. Otherwise the trip gets your settings (often lower accuracy,
  a larger distance filter, no background updates) and the vehicle barely moves.
