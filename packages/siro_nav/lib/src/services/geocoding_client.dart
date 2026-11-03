import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:siro_nav_core/siro_nav_core.dart';

/// A place returned by Siro search or reverse geocoding.
class NavPlace {
  final String id;
  final String name;
  final String? address;
  final String? category;
  final double latitude;
  final double longitude;

  /// Distance from the search centre, when the server sent it.
  final double? distanceMeters;

  /// The full result, for fields this class does not model.
  final Map<String, dynamic> raw;

  const NavPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category,
    this.distanceMeters,
    this.raw = const {},
  });

  NavPoint get point => NavPoint.fromLatLng(latitude, longitude);

  factory NavPlace.fromJson(Map<String, dynamic> m) {
    double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
    final loc =
        m['geometry'] is Map ? (m['geometry'] as Map)['location'] : null;
    return NavPlace(
      id: (m['id'] ?? m['place_id'] ?? '').toString(),
      name:
          (m['name_ar'] ?? m['name_display'] ?? m['name'] ?? m['name_en'] ?? '')
              .toString(),
      address: (m['full_address'] ??
              m['address_text'] ??
              m['formatted_address'] ??
              m['address'])
          ?.toString(),
      category: (m['category_label_ar'] ?? m['category'])?.toString(),
      latitude:
          n(m['lat'] ?? m['latitude'] ?? (loc is Map ? loc['lat'] : null)) ?? 0,
      longitude:
          n(m['lng'] ?? m['longitude'] ?? (loc is Map ? loc['lng'] : null)) ??
              0,
      distanceMeters: n(m['distance_m']),
      raw: m,
    );
  }
}

/// Search, autocomplete and reverse geocoding on the Siro Maps API, with the
/// same key as routing. Use it to let the driver or rider pick a destination.
class SiroGeocodingClient {
  final NavConfig config;
  final http.Client _http;

  SiroGeocodingClient({required this.config, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Places matching [query]. Pass [near] to rank nearby places first.
  Future<List<NavPlace>> search(String query,
          {NavPoint? near, String? country}) =>
      _places('geocoding/search', {
        'q': query,
        if (near != null) 'lat': '${near.latitude}',
        if (near != null) 'lng': '${near.longitude}',
        if (country != null) 'country': country,
      });

  /// Fast suggestions while the user types (2 characters or more).
  Future<List<NavPlace>> autocomplete(String query, {NavPoint? near}) =>
      query.trim().length < 2
          ? Future.value(const [])
          : _places('geocoding/autocomplete', {
              'q': query,
              if (near != null) 'lat': '${near.latitude}',
              if (near != null) 'lng': '${near.longitude}',
            });

  /// The address at [point], nearest match first.
  Future<List<NavPlace>> reverse(NavPoint point) =>
      _places('geocoding/reverse', {
        'lat': '${point.latitude}',
        'lng': '${point.longitude}',
      });

  Future<List<NavPlace>> _places(String path, Map<String, String> query) async {
    final uri =
        Uri.parse('${config.baseUrl}/$path').replace(queryParameters: query);
    final response = await _http.get(uri, headers: {
      'x-api-key': config.apiKey,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 10));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Siro API key rejected (${response.statusCode})');
    }
    if (response.statusCode != 200) return const [];
    final decoded =
        json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    final items = decoded is List
        ? decoded
        : decoded is Map && decoded['results'] is List
            ? decoded['results'] as List
            : const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) NavPlace.fromJson(item),
    ].where((p) => p.latitude != 0 || p.longitude != 0).toList();
  }

  void dispose() => _http.close();
}
