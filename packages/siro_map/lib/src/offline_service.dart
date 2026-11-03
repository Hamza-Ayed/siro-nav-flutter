// وظيفة الملف: تنفيذ أو إعداد offline service ضمن هذا الجزء من المشروع.
import 'dart:async';
import 'dart:io';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:math' as math;

/// Service for managing offline map regions in Siro Maps.
///
/// This service allows you to download map tiles for a specific region
/// so they can be accessed without an internet connection.
class SiroOfflineService {
  static final SiroOfflineService instance = SiroOfflineService._();
  SiroOfflineService._();

  bool _isDownloading = false;
  LatLng? _lastDownloadedCenter;
  Timer? _debounceTimer;

  /// Calculate bounding box for a given center and radius in km.
  LatLngBounds _calculateBounds(LatLng center, double radiusKm) {
    const double earthRadius = 6371.0;

    // Latitude degrees per km
    double latDelta = (radiusKm / earthRadius) * (180 / math.pi);
    // Longitude degrees per km at given latitude
    double lngDelta = (radiusKm / earthRadius) *
        (180 / math.pi) /
        math.cos(center.latitude * math.pi / 180);

    return LatLngBounds(
      southwest:
          LatLng(center.latitude - latDelta, center.longitude - lngDelta),
      northeast:
          LatLng(center.latitude + latDelta, center.longitude + lngDelta),
    );
  }

  /// Downloads map tiles for a specified radius around a coordinate.
  ///
  /// [center] is the midpoint of the region.
  /// [styleUrl] is the style to download (e.g. from SiroStyles).
  /// [radiusKm] defines the extent of the download.
  void downloadRegion(
    LatLng center, {
    required String styleUrl,
    double radiusKm = 5.0,
    double minZoom = 6.0,
    double maxZoom = 16.0,
  }) {
    // Debounce: Wait for user to stop moving for 2 seconds before starting download
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      if (_isDownloading) return;

      // Avoid re-downloading if the user hasn't moved significantly (e.g. > 3km)
      if (_lastDownloadedCenter != null) {
        double distance = _calculateDistance(center, _lastDownloadedCenter!);
        if (distance < 3.0) return;
      }

      _isDownloading = true;

      try {
        final bounds = _calculateBounds(center, radiusKm);

        // iOS native crash guard for relative assets - only download remote styles
        // because local assets are already on disk.
        if (styleUrl.startsWith('asset://') || (Platform.isIOS && !styleUrl.startsWith('http'))) {
           return;
        }

        final regionDefinition = OfflineRegionDefinition(
          bounds: bounds,
          mapStyleUrl: styleUrl,
          minZoom: minZoom,
          maxZoom: maxZoom,
        );

        _lastDownloadedCenter = center;

        // Use maplibre_gl top-level function
        await downloadOfflineRegion(
          regionDefinition,
          metadata: {
            'name': 'Siro-${center.latitude}-${center.longitude}',
            'downloadDate': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        // Silently fail or log in debug
        print("❌ [OfflineService] Download failed: $e");
      } finally {
        _isDownloading = false;
      }
    });
  }

  /// Helper to calculate distance in km using Haversine formula.
  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 -
        c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) *
            c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  /// Clears all offline map regions and tiles.
  Future<void> clearCache() async {
    try {
      final List<OfflineRegion> regions = await getListOfRegions();
      for (var region in regions) {
        await deleteOfflineRegion(region.id);
      }
    } catch (_) {}
  }
}
