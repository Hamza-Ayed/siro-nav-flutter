// وظيفة الملف: تنفيذ أو إعداد types ضمن هذا الجزء من المشروع.
import 'dart:ui';
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import '../siro_map_controller.dart';

// ─────────────────────────────────────────────────────────────
// SiroMapType  (mirrors MapType in google_maps_flutter)
// ─────────────────────────────────────────────────────────────

/// The visual style of the base map tiles.
enum SiroMapType {
  /// No base map tiles.
  none,

  /// Dark premium Obsidian style — the Siro default.
  normal,

  /// High-contrast light style.
  light,

  /// Satellite imagery with road labels overlaid.
  satellite,

  /// True 3D Topographic and Terrain Elevation style with DEM displacement.
  terrain,
}

/// Backward compatibility alias for developers migrating from `google_maps_flutter`.
typedef MapType = SiroMapType;


// ─────────────────────────────────────────────────────────────
// MinMaxZoomPreference  (identical to google_maps_flutter)
// ─────────────────────────────────────────────────────────────

/// Preferred zoom level constraints for the camera.
class MinMaxZoomPreference {
  const MinMaxZoomPreference(this.minZoom, this.maxZoom);

  final double? minZoom;
  final double? maxZoom;

  /// Unbounded zoom (default).
  static const MinMaxZoomPreference unbounded =
      MinMaxZoomPreference(null, null);

  @override
  String toString() => 'MinMaxZoomPreference($minZoom, $maxZoom)';
}

// ─────────────────────────────────────────────────────────────
// CameraTargetBounds  (identical to google_maps_flutter)
// ─────────────────────────────────────────────────────────────

/// Constrains the camera target to a [LatLngBounds] region.
class CameraTargetBounds {
  const CameraTargetBounds(this.bounds);

  final mgl.LatLngBounds? bounds;

  /// Unbounded (default).
  static const CameraTargetBounds unbounded = CameraTargetBounds(null);

  @override
  String toString() => 'CameraTargetBounds($bounds)';
}

// ─────────────────────────────────────────────────────────────
// Typedefs  (same names as google_maps_flutter)
// ─────────────────────────────────────────────────────────────

/// Callback when the map is created.
typedef MapCreatedCallback = void Function(SiroMapController controller);

/// Generic callback for an argument of type [T].
typedef ArgumentCallback<T> = void Function(T argument);

/// Callback for camera position changes.
typedef CameraPositionCallback = void Function(CameraPosition position);

/// Defines a particular camera position.
///
/// This class mirrors `CameraPosition` from `google_maps_flutter`.
class CameraPosition {
  /// Creates an immutable representation of the [CameraPosition].
  const CameraPosition({
    required this.target,
    this.bearing = 0.0,
    this.tilt = 0.0,
    this.zoom = 0.0,
  });

  /// The location that the camera is pointing at.
  final mgl.LatLng target;

  /// The direction that the camera is facing in degrees clockwise from north.
  final double bearing;

  /// The angle, in degrees, of the camera angle from the perpendicular to the map's surface.
  final double tilt;

  /// The zoom level of the camera.
  final double zoom;

  /// Serializes this [CameraPosition] to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'target': [target.latitude, target.longitude],
      'bearing': bearing,
      'tilt': tilt,
      'zoom': zoom,
    };
  }

  /// Deserializes a [CameraPosition] from a map.
  static CameraPosition fromMap(Map<String, dynamic> json) {
    final targetList = json['target'] as List<dynamic>;
    return CameraPosition(
      target: mgl.LatLng(targetList[0] as double, targetList[1] as double),
      bearing: (json['bearing'] as num).toDouble(),
      tilt: (json['tilt'] as num).toDouble(),
      zoom: (json['zoom'] as num).toDouble(),
    );
  }

  /// Internal: Converts to MapLibre's [mgl.CameraPosition].
  mgl.CameraPosition toMapLibre() {
    return mgl.CameraPosition(
      target: target,
      bearing: bearing,
      tilt: tilt,
      zoom: zoom,
    );
  }

  /// Internal: Creates from MapLibre's [mgl.CameraPosition].
  static CameraPosition fromMapLibre(mgl.CameraPosition pos) {
    return CameraPosition(
      target: pos.target,
      bearing: pos.bearing,
      tilt: pos.tilt,
      zoom: pos.zoom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CameraPosition) return false;
    return target == other.target &&
        bearing == other.bearing &&
        tilt == other.tilt &&
        zoom == other.zoom;
  }

  @override
  int get hashCode => Object.hash(target, bearing, tilt, zoom);

  @override
  String toString() =>
      'CameraPosition(target: $target, zoom: $zoom, bearing: $bearing, tilt: $tilt)';
}

/// Defines a camera move.
///
/// This class mirrors `CameraUpdate` from `google_maps_flutter` but
/// works with our custom [CameraPosition].
class CameraUpdate {
  CameraUpdate._(this._raw);
  final mgl.CameraUpdate _raw;

  /// Returns a [CameraUpdate] that moves the camera to the specified [position].
  static CameraUpdate newCameraPosition(CameraPosition position) =>
      CameraUpdate._(mgl.CameraUpdate.newCameraPosition(position.toMapLibre()));

  /// Returns a [CameraUpdate] that moves the camera to the specified [latLng].
  static CameraUpdate newLatLng(mgl.LatLng latLng) =>
      CameraUpdate._(mgl.CameraUpdate.newLatLng(latLng));

  /// Returns a [CameraUpdate] that moves the camera to the specified [bounds].
  static CameraUpdate newLatLngBounds(
    mgl.LatLngBounds bounds, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      CameraUpdate._(mgl.CameraUpdate.newLatLngBounds(
        bounds,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ));

  /// Returns a [CameraUpdate] that moves the camera to the specified [latLng] and [zoom].
  static CameraUpdate newLatLngZoom(mgl.LatLng latLng, double zoom) =>
      CameraUpdate._(mgl.CameraUpdate.newLatLngZoom(latLng, zoom));

  /// Returns a [CameraUpdate] that scrolls the camera by the specified pixels.
  static CameraUpdate scrollBy(double dx, double dy) =>
      CameraUpdate._(mgl.CameraUpdate.scrollBy(dx, dy));

  /// Returns a [CameraUpdate] that zooms the camera by the specified amount.
  static CameraUpdate zoomBy(double amount, [Offset? focus]) =>
      CameraUpdate._(mgl.CameraUpdate.zoomBy(amount, focus));

  /// Returns a [CameraUpdate] that zooms in the camera.
  static CameraUpdate zoomIn() => CameraUpdate._(mgl.CameraUpdate.zoomIn());

  /// Returns a [CameraUpdate] that zooms out the camera.
  static CameraUpdate zoomOut() => CameraUpdate._(mgl.CameraUpdate.zoomOut());

  /// Returns a [CameraUpdate] that zooms the camera to the specified [zoom] level.
  static CameraUpdate zoomTo(double zoom) =>
      CameraUpdate._(mgl.CameraUpdate.zoomTo(zoom));

  /// Internal: Converts to MapLibre's [mgl.CameraUpdate].
  mgl.CameraUpdate toMapLibre() => _raw;
}
