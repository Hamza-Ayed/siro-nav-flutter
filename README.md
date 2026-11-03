# Siro Nav for Flutter

In-app turn-by-turn navigation on Siro Maps, for ride-hailing and delivery
apps. The driver never leaves your app: the route, the map, Arabic voice
guidance and the trip meter all run inside it.

| Package | What it is |
|---|---|
| [`packages/siro_nav`](packages/siro_nav) | The SDK: controller, drop-in `SiroNavView`, voice, trip meter, geocoding |
| [`packages/siro_nav_core`](packages/siro_nav_core) | Pure Dart engine: map matching, instructions, rerouting, telemetry |
| [`packages/siro_map`](packages/siro_map) | The Siro map widget the view draws on |

Start with [`packages/siro_nav/README.md`](packages/siro_nav/README.md).

## Quick start

```dart
final nav = await SiroNavController.create(
  config: NavConfig(apiKey: 'YOUR_SIRO_API_KEY'),
);

// Leg 1: to the rider. Origin = the phone's GPS position.
await nav.startNavigation(destination: rider, phase: NavTripPhase.pickup);

// Leg 2: the ride, metered with your own tariff.
await nav.startNavigation(
  destination: dropOff,
  phase: NavTripPhase.trip,
  fare: const NavFareConfig(baseFare: 0.5, perKilometer: 0.35, perWaitingMinute: 0.05),
);

// Show it:
SiroNavView(controller: nav, onExit: () => Navigator.pop(context));

// After the trip ends: nav.lastTrip.value has distance, waiting time and fare.
```

## Tests

```bash
cd packages/siro_nav_core && dart test
cd packages/siro_nav && flutter test
```
