import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:siro_nav/siro_nav.dart';

// Three points about 1.1 km due north, encoded with precision 5.
const _encodedRoute = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

RoutingClient _routeClient() {
  final body = jsonEncode({
    'points': _encodedRoute,
    'distance': 1234.5,
    'duration': 210.0,
    'instructions': [
      {
        'text': 'انطلق',
        'sign': 0,
        'street_name': 'شارع الملك',
        'distance': 800.0,
        'time': 60000,
        'interval': [0, 1],
      },
    ],
    'speedCameras': [],
  });
  final mock = MockClient((request) async => http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json'},
      ));
  return RoutingClient(
      config: NavConfig(apiKey: 'siro_live_test'), httpClient: mock);
}

void main() {
  test('a simulated trip starts, drives to the destination, and ends by itself',
      () async {
    final controller = SiroNavController(
      config: NavConfig(apiKey: 'siro_live_test'),
      routingClient: _routeClient(),
    );
    final origin = NavPoint.fromLatLng(38.5, -120.2);
    final destination = NavPoint.fromLatLng(43.252, -126.453);

    final started = await controller.startNavigation(
      origin: origin,
      destination: destination,
      simulate: true,
      // The test route is about 750 km long: 1000 km/s reaches the end in a tick or two.
      simulationSpeedKmh: 3600000,
    );

    expect(started, isTrue);
    expect(controller.isNavigating.value, isTrue);
    expect(controller.route.value, isNotNull);
    expect(controller.route.value!.polyline, hasLength(3));

    // Wait for arrival: the engine stops guidance within 20 m of the end.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (controller.isNavigating.value && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(controller.isNavigating.value, isFalse);
    expect(controller.route.value, isNull);

    // The summary survives the end of the trip, for billing.
    final summary = controller.lastTrip.value!;
    expect(summary.arrived, isTrue);
    expect(summary.phase, NavTripPhase.trip);
    await controller.dispose();
  });

  test('a route error is reported in activeError and nothing starts', () async {
    final mock =
        MockClient((request) async => http.Response('{"message":"x"}', 401));
    final controller = SiroNavController(
      config: NavConfig(apiKey: 'siro_live_test'),
      routingClient: RoutingClient(
          config: NavConfig(apiKey: 'siro_live_test'), httpClient: mock),
    );

    final started = await controller.startNavigation(
      origin: NavPoint.fromLatLng(31.95, 35.91),
      destination: NavPoint.fromLatLng(31.97, 35.92),
    );

    expect(started, isFalse);
    expect(controller.isNavigating.value, isFalse);
    expect(controller.activeError.value, contains('مفتاح API'));
    await controller.dispose();
  });
  test('a GPS trip starts from the first fix, not from a fixed origin',
      () async {
    final requested = <Uri>[];
    final mock = MockClient((request) async {
      requested.add(request.url);
      return http.Response.bytes(
        utf8.encode(jsonEncode({'points': _encodedRoute, 'instructions': []})),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final fixes = StreamController<NavPoint>();
    final controller = SiroNavController(
      config: NavConfig(apiKey: 'siro_live_test'),
      routingClient: RoutingClient(
          config: NavConfig(apiKey: 'siro_live_test'), httpClient: mock),
      positionSource: (_) => fixes.stream,
      firstFixTimeout: const Duration(seconds: 2),
    );

    final started = controller.startNavigation(
        destination: NavPoint.fromLatLng(31.9735, 35.9235));
    fixes.add(NavPoint.fromLatLng(31.9541, 35.9108));

    expect(await started, isTrue);
    expect(requested.single.queryParameters['fromLat'], '31.9541');
    expect(requested.single.queryParameters['fromLng'], '35.9108');
    expect(controller.vehiclePosition.value?.latitude, closeTo(31.9541, 1e-6));

    await controller.dispose();
    await fixes.close();
  });

  test('a GPS trip with no fix in time reports it and does not start',
      () async {
    final fixes = StreamController<NavPoint>();
    final controller = SiroNavController(
      config: NavConfig(apiKey: 'siro_live_test'),
      positionSource: (_) => fixes.stream,
      firstFixTimeout: const Duration(milliseconds: 100),
    );

    final started = await controller.startNavigation(
      destination: NavPoint.fromLatLng(31.9735, 35.9235),
    );

    expect(started, isFalse);
    expect(controller.isNavigating.value, isFalse);
    expect(controller.activeError.value, contains('GPS'));
    await controller.dispose();
    await fixes.close();
  });

  test('heading and speed are derived from movement when the GPS gives none',
      () async {
    final mock = MockClient((request) async => http.Response.bytes(
          utf8.encode(
              jsonEncode({'points': _encodedRoute, 'instructions': []})),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final fixes = StreamController<NavPoint>();
    final controller = SiroNavController(
      config: NavConfig(apiKey: 'siro_live_test'),
      routingClient: RoutingClient(
          config: NavConfig(apiKey: 'siro_live_test'), httpClient: mock),
      positionSource: (_) => fixes.stream,
      lastKnownPosition: () async => null,
    );
    final t0 = DateTime(2026, 11, 3, 12);
    NavPoint fix(double lng, int s) => NavPoint(
          latitude: 31.95,
          longitude: lng,
          heading: -1,
          speedKmh: -1,
          timestamp: t0.add(Duration(seconds: s)),
        );

    final started = controller.startNavigation(
        destination: NavPoint.fromLatLng(31.97, 35.92));
    fixes.add(fix(35.9000, 0));
    expect(await started, isTrue);
    // About 9.5 m east in 2 seconds: heading ~90, speed ~17 km/h.
    fixes.add(fix(35.9001, 2));
    await Future<void>.delayed(Duration.zero);

    final last = controller.lastGpsFix.value!;
    expect(last.heading, closeTo(90, 1));
    expect(last.speedKmh, closeTo(17, 2));

    await controller.dispose();
    await fixes.close();
  });
}
