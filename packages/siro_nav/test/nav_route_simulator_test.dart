import 'package:flutter_test/flutter_test.dart';
import 'package:siro_nav/siro_nav.dart';

NavRoute _straightRoute() {
  // Roughly 1.1 km due north, in three vertices.
  final polyline = [
    NavPoint.fromLatLng(31.9500, 35.9100),
    NavPoint.fromLatLng(31.9550, 35.9100),
    NavPoint.fromLatLng(31.9600, 35.9100),
  ];
  return NavRoute(
    id: 'test',
    routeName: 'test',
    polyline: polyline,
    steps: const [],
    speedCameras: const [],
    totalDistanceMeters: 1100,
    totalDurationSeconds: 60,
  );
}

void main() {
  test('starts at the first vertex and heads north along the route', () {
    final sim = NavRouteSimulator(route: _straightRoute());

    final start = sim.pointAt(0);
    expect(start.latitude, closeTo(31.95, 1e-6));
    expect(start.heading, closeTo(0, 1));
    sim.dispose();
  });

  test('moves linearly by distance and clamps at the end', () {
    final sim = NavRouteSimulator(route: _straightRoute());
    final half = sim.totalMeters / 2;

    final middle = sim.pointAt(half);
    expect(middle.latitude, closeTo(31.9550, 1e-4));

    final beyond = sim.pointAt(sim.totalMeters * 10);
    expect(beyond.latitude, closeTo(31.9600, 1e-6));
    sim.dispose();
  });

  test('emits points while running and stops when the route ends', () async {
    final sim = NavRouteSimulator(
      route: _straightRoute(),
      speedKmh:
          36000, // 10 km per second: 1 km per 100 ms tick, so the route ends in 2 ticks
      tick: const Duration(milliseconds: 100),
    );
    final emitted = <NavPoint>[];
    final sub = sim.points.listen(emitted.add);

    sim.start();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(emitted.length, greaterThan(1));
    expect(emitted.last.latitude, closeTo(31.9600, 1e-6));
    expect(sim.isRunning, isFalse);

    await sub.cancel();
    sim.dispose();
  });

  test('switchRoute continues from the new route start', () {
    final sim = NavRouteSimulator(route: _straightRoute());
    sim.switchRoute(NavRoute(
      id: 'reroute',
      routeName: 'reroute',
      polyline: [
        NavPoint.fromLatLng(31.9600, 35.9100),
        NavPoint.fromLatLng(31.9600, 35.9200),
      ],
      steps: const [],
      speedCameras: const [],
      totalDistanceMeters: 800,
      totalDurationSeconds: 60,
    ));

    expect(sim.travelledMeters, 0);
    expect(sim.pointAt(0).latitude, closeTo(31.9600, 1e-6));
    sim.dispose();
  });
}
