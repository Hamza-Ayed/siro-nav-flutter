import 'package:siro_nav_core/siro_nav_core.dart';
import 'package:test/test.dart';

NavRoute _route() => NavRoute(
      id: 'r',
      routeName: 'r',
      polyline: [
        for (var i = 0; i <= 100; i++)
          NavPoint.fromLatLng(31.9 + i * 0.0005, 35.9),
      ],
      steps: const [],
      speedCameras: const [],
      totalDistanceMeters: 5500,
      totalDurationSeconds: 400,
    );

Future<List<NavEvent>> _drive(double lngOffset) async {
  final engine = NavigationEngine(
    config: NavConfig(apiKey: 'siro_live_test', offRouteDebounceSeconds: 0),
  );
  final events = <NavEvent>[];
  engine.events.listen(events.add);
  await engine.startNavigation(_route());
  // About 10 m per 0.0001 degree of longitude here.
  engine.updateLocation(NavPoint.fromLatLng(31.9100, 35.9 + lngOffset));
  await Future<void>.delayed(Duration.zero);
  engine.dispose();
  return events;
}

void main() {
  test('a fix about 50 m off the route does not start a reroute', () async {
    final events = await _drive(0.00055); // about 50 m
    expect(events.whereType<RerouteTriggeredEvent>(), isEmpty);
  });

  test('a fix about 70 m off the route starts a reroute', () async {
    final events = await _drive(0.00078); // about 70 m
    expect(events.whereType<RerouteTriggeredEvent>(), isNotEmpty);
  });

  test('near the route but off the road, the real position is drawn', () async {
    final engine =
        NavigationEngine(config: NavConfig(apiKey: 'siro_live_test'));
    await engine.startNavigation(_route());

    // About 35 m east of the route: still on it for rerouting, but not on the road.
    final house = NavPoint.fromLatLng(31.9100, 35.9 + 0.00037);
    engine.updateLocation(house);
    expect(engine.displayPoint!.longitude, closeTo(house.longitude, 1e-9));

    // About 5 m from the route: drawn on the road.
    engine.updateLocation(NavPoint.fromLatLng(31.9102, 35.9 + 0.00005));
    expect(engine.displayPoint!.longitude, closeTo(35.9, 1e-6));
    engine.dispose();
  });
}
