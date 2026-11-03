import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:siro_nav/siro_nav.dart';

const _encodedRoute = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

/// Shape of a real `/api/maps/route?steps=true` response (fields we read).
Map<String, dynamic> _serverBody() => {
      'points': _encodedRoute,
      'distance': 1234.5,
      'duration': 210.0,
      'routeName': 'عبر شارع الملك',
      'instructions': [
        {
          'text': 'انطلق',
          'sign': 0,
          'street_name': 'شارع الملك',
          'distance': 800.0,
          'time': 60000,
          'interval': [0, 1],
        },
        {
          'text': 'انعطف يميناً',
          'sign': 2,
          'street_name': 'شارع الجامعة',
          'distance': 434.5,
          'time': 150000,
          'exit_number': null,
          'interval': [1, 2],
        },
      ],
      'trafficFactor': 1.3,
      'liveTraffic': {'coverage': 0.6, 'ageMinutes': 4},
      'ecoMetrics': {
        'estimatedGasolineLiters': 0.42,
        'estimatedCost': 0.38,
        'currency': 'JOD',
        'estimatedCostFormatted': '0.38 د.أ',
        'co2Kg': 0.97,
        'ecoScore': 88,
      },
      'elevationSummary': {
        'totalAscentMeters': 54,
        'totalDescentMeters': 12,
        'maxInclinePercent': 9.5,
        'maxDeclinePercent': -4,
        'steepWarnings': [
          {
            'text': 'صعود حاد',
            'slopePercent': 9.5,
            'lengthM': 120,
            'startIndex': 0,
            'endIndex': 1
          },
        ],
      },
      'congestionSegments': [
        {
          'startIndex': 0,
          'endIndex': 1,
          'level': 'heavy',
          'color': '#ef4444',
          'factor': 1.6
        },
      ],
      'speedLimits': [
        {'startIndex': 0, 'endIndex': 2, 'kmh': 60},
      ],
      'speedCameras': [
        {'lat': 40.7, 'lng': -120.95, 'speedLimitKmh': 80},
        {'lat': 43.0, 'lng': -126.0, 'speedLimitKmh': null},
      ],
    };

RoutingClient _clientReturning(int status, String body) {
  final mock = MockClient((request) async => http.Response.bytes(
        utf8.encode(body),
        status,
        headers: {
          'content-type': 'application/json'
        }, // no charset, as some servers send
      ));
  return RoutingClient(
    config: NavConfig(apiKey: 'siro_live_test'),
    httpClient: mock,
  );
}

void main() {
  group('RoutingClient.parseRoute', () {
    test('reads geometry, steps, cameras and totals from the server shape', () {
      final route = RoutingClient.parseRoute(jsonEncode(_serverBody()));

      expect(route.polyline, hasLength(3));
      expect(route.steps, hasLength(2));
      expect(route.totalDistanceMeters, 1234.5);
      expect(route.totalDurationSeconds, 210.0);
      expect(route.routeName, 'عبر شارع الملك');

      final turn = route.steps[1];
      expect(turn.maneuverType, 2);
      expect(turn.instruction, 'انعطف يميناً');
      expect(turn.durationSeconds, 150.0);
      // The maneuver is where the instruction's segment starts (index 1).
      expect(turn.lat, closeTo(40.7, 1e-5));
      expect(turn.lng, closeTo(-120.95, 1e-5));
    });

    test('keeps unknown speed limits at 0 so they are never flagged', () {
      final route = RoutingClient.parseRoute(jsonEncode(_serverBody()));

      expect(route.speedCameras, hasLength(2));
      expect(route.speedCameras[0].speedLimitKmh, 80);
      expect(route.speedCameras[1].speedLimitKmh, 0);
    });

    test('rejects a body with no usable geometry', () {
      expect(
        () => RoutingClient.parseRoute(
            jsonEncode({'points': '', 'instructions': []})),
        throwsA(isA<NavRouteException>()
            .having((e) => e.code, 'code', 'ERR_NO_ROUTE')),
      );
    });

    test('rejects a body that is not JSON', () {
      expect(
        () => RoutingClient.parseRoute('<html>502</html>'),
        throwsA(isA<NavRouteException>()
            .having((e) => e.code, 'code', 'ERR_BAD_RESPONSE')),
      );
    });
  });

  group('RoutingClient.getRoute', () {
    final origin = NavPoint.fromLatLng(31.95, 35.91);
    final destination = NavPoint.fromLatLng(31.97, 35.92);

    test('calls the real route endpoint with the key and stops', () async {
      late Uri requested;
      late Map<String, String> headers;
      final mock = MockClient((request) async {
        requested = request.url;
        headers = request.headers;
        return http.Response.bytes(
          utf8.encode(jsonEncode(_serverBody())),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = RoutingClient(
        config: NavConfig(apiKey: 'siro_live_test'),
        httpClient: mock,
      );

      await client.getRoute(
        origin: origin,
        destination: destination,
        waypoints: [NavPoint.fromLatLng(31.96, 35.915)],
      ).catchError((Object e) {
        fail('getRoute failed with ${e is NavRouteException ? e.cause : e}');
      });

      expect(requested.path, '/api/maps/route');
      expect(requested.queryParameters['fromLat'], '31.95');
      expect(requested.queryParameters['toLng'], '35.92');
      expect(requested.queryParameters['stop1Lat'], '31.96');
      expect(requested.queryParameters['steps'], 'true');
      expect(headers['x-api-key'], 'siro_live_test');
    });

    test('maps HTTP 401 to an unauthorized-key error', () async {
      final client =
          _clientReturning(401, '{"message":"API Key (x-api-key) is missing"}');

      expect(
        () => client.getRoute(origin: origin, destination: destination),
        throwsA(isA<NavRouteException>()
            .having((e) => e.code, 'code', 'ERR_UNAUTHORIZED_API_KEY')
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('maps HTTP 422 to an out-of-coverage error with the server message',
        () async {
      final client = _clientReturning(422, '{"message":"خارج التغطية"}');

      expect(
        () => client.getRoute(origin: origin, destination: destination),
        throwsA(isA<NavRouteException>()
            .having((e) => e.cause, 'cause', isNull)
            .having((e) => e.code, 'code', 'ERR_OUT_OF_COVERAGE')
            .having((e) => e.message, 'message', 'خارج التغطية')),
      );
    });
  });

  test('route details carry fuel, terrain, traffic and speed limits', () {
    final route = RoutingClient.parseRoute(jsonEncode(_serverBody()));
    final d = route.details!;

    expect(d.trafficFactor, 1.3);
    expect(d.liveTrafficCoverage, 0.6);
    expect(d.fuel!.gasolineLiters, 0.42);
    expect(d.fuel!.currency, 'JOD');
    expect(d.fuel!.ecoScore, 88);
    expect(d.elevation!.totalAscentMeters, 54);
    expect(d.elevation!.steepStretches.single.isClimb, isTrue);
    expect(d.congestion.single.level, 'heavy');
    expect(d.speedLimitAt(1), 60);
    expect(d.speedLimitAt(5), isNull);
  });
}
