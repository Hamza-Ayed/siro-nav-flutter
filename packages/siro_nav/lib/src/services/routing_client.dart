import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:siro_nav_core/siro_nav_core.dart';

/// Error raised when a route cannot be fetched. [code] is stable for developers
/// to branch on, [message] is safe to show to the driver.
class NavRouteException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  /// The underlying error, for logs. Not meant for the driver.
  final Object? cause;

  const NavRouteException(this.code, this.message,
      {this.statusCode, this.cause});

  @override
  String toString() => '$code: $message';
}

/// Fetches routes from the Siro Maps routing API (`GET /api/maps/route`).
///
/// The server returns the geometry as an encoded polyline in `points`, the turn
/// list in `instructions` (only when `steps=true`), and the speed cameras on the
/// route in `speedCameras`.
class RoutingClient {
  final NavConfig config;
  final http.Client _httpClient;

  RoutingClient({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Requests a turn-by-turn route from [origin] to [destination], through
  /// [waypoints] in order. The server allows up to 3 stops.
  Future<NavRoute> getRoute({
    required NavPoint origin,
    required NavPoint destination,
    List<NavPoint> waypoints = const [],
    String lang = 'ar',
  }) async {
    final query = <String, String>{
      'fromLat': '${origin.latitude}',
      'fromLng': '${origin.longitude}',
      'toLat': '${destination.latitude}',
      'toLng': '${destination.longitude}',
      'steps': 'true',
      'alternatives': 'false',
      'lang': lang,
    };
    for (var i = 0; i < waypoints.length; i++) {
      query['stop${i + 1}Lat'] = '${waypoints[i].latitude}';
      query['stop${i + 1}Lng'] = '${waypoints[i].longitude}';
    }

    final uri = Uri.parse('${config.baseUrl}/maps/route')
        .replace(queryParameters: query);

    final http.Response response;
    try {
      response = await _httpClient.get(uri, headers: {
        'x-api-key': config.apiKey,
        'Accept': 'application/json',
        'User-Agent': 'SiroNavFlutter-SDK/0.1.0',
      }).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const NavRouteException(
        'ERR_ROUTE_TIMEOUT',
        'انتهت مهلة حساب المسار، تحقق من الاتصال وحاول مرة أخرى.',
      );
    } catch (e) {
      throw NavRouteException(
        'ERR_NETWORK',
        'تعذر الوصول إلى خادم سيرو للمسارات.',
        cause: e,
      );
    }

    // Decode the bytes as UTF-8 ourselves: package:http falls back to Latin-1
    // when the server omits a charset, which would garble Arabic text.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw NavRouteException(
        'ERR_UNAUTHORIZED_API_KEY',
        'مفتاح API غير صالح أو منتهي الاشتراك.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 422) {
      throw NavRouteException(
        'ERR_OUT_OF_COVERAGE',
        _serverMessage(body) ?? 'الموقع المحدد خارج نطاق شبكة الطرق المعتمدة.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw NavRouteException(
        'ERR_ROUTE_FAILED',
        _serverMessage(body) ??
            'تعذر حساب المسار حالياً (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return parseRoute(body);
  }

  /// Converts a `/api/maps/route` response body into a [NavRoute].
  static NavRoute parseRoute(String body) {
    final Map<String, dynamic> data;
    try {
      data = json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const NavRouteException(
          'ERR_BAD_RESPONSE', 'رد غير متوقع من خادم المسارات.');
    }

    final encoded = data['points'] as String? ?? '';
    final List<NavPoint> polyline;
    try {
      polyline = PolylineCodec.decode(encoded);
    } on FormatException {
      throw const NavRouteException(
          'ERR_BAD_RESPONSE', 'هندسة المسار غير صالحة.');
    }
    if (polyline.length < 2) {
      throw const NavRouteException(
          'ERR_NO_ROUTE', 'لا يوجد مسار قابل للسير بين النقطتين.');
    }

    final instructions = data['instructions'] as List? ?? const [];
    final steps = <NavStep>[];
    for (var i = 0; i < instructions.length; i++) {
      final inst = instructions[i] as Map<String, dynamic>;
      final interval = (inst['interval'] as List?) ?? const [0, 0];
      final startIdx =
          _clampIndex((interval[0] as num).toInt(), polyline.length);
      final endIdx = _clampIndex(
        (interval.length > 1 ? interval[1] as num : interval[0] as num).toInt(),
        polyline.length,
      );
      // The maneuver happens where this instruction's segment begins.
      final maneuver = polyline[startIdx];

      steps.add(NavStep(
        index: i,
        instruction: inst['text']?.toString() ?? '',
        streetName: inst['street_name']?.toString() ?? '',
        maneuverType: (inst['sign'] as num?)?.toInt() ?? 0,
        exitNumber: (inst['exit_number'] as num?)?.toInt(),
        distanceMeters: (inst['distance'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: ((inst['time'] as num?)?.toDouble() ?? 0.0) / 1000.0,
        lat: maneuver.latitude,
        lng: maneuver.longitude,
        coordinateInterval: [startIdx, endIdx],
        slopePercent: (inst['slopePercent'] as num?)?.toDouble(),
        slopeWarning: inst['slopeWarning']?.toString(),
      ));
    }

    final cameras = <SpeedCamera>[];
    final rawCameras = data['speedCameras'] as List? ?? const [];
    for (var i = 0; i < rawCameras.length; i++) {
      final cam = rawCameras[i] as Map<String, dynamic>;
      cameras.add(SpeedCamera(
        id: 'cam_${cam['lat']}_${cam['lng']}_$i',
        latitude: (cam['lat'] as num).toDouble(),
        longitude: (cam['lng'] as num).toDouble(),
        // 0 means the limit is unknown: the camera is announced, never flagged.
        speedLimitKmh: (cam['speedLimitKmh'] as num?)?.toInt() ?? 0,
        type: 'fixed',
        alertDistanceMeters: 300.0,
      ));
    }

    return NavRoute(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}',
      routeName: data['routeName']?.toString() ?? 'المسار المباشر الأسرع',
      polyline: polyline,
      steps: steps,
      speedCameras: cameras,
      totalDistanceMeters: (data['distance'] as num?)?.toDouble() ?? 0.0,
      totalDurationSeconds: (data['duration'] as num?)?.toDouble() ?? 0.0,
      details: NavRouteDetails.fromJson(data),
    );
  }

  static int _clampIndex(int value, int length) => value.clamp(0, length - 1);

  static String? _serverMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _httpClient.close();
  }
}
