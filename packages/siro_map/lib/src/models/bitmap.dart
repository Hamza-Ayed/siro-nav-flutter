// وظيفة الملف: تنفيذ أو إعداد bitmap ضمن هذا الجزء من المشروع.
import 'dart:typed_data' show Uint8List;

/// Defines a bitmap image for use as a [Marker] icon.
///
/// This class mirrors `BitmapDescriptor` from `google_maps_flutter`.
/// Internally it resolves to a MapLibre image name or inline bytes.
class SiroBitmap {
  const SiroBitmap._({
    required this.mapLibreImageId,
    this.size,
    this.bytes,
    this.assetName,
  });

  /// The image name used in MapLibre style expressions.
  final String mapLibreImageId;

  /// Optional size multiplier (MapLibre iconSize).
  final double? size;


  /// Raw PNG/JPEG bytes (used with [fromBytes]).
  final Uint8List? bytes;

  /// Flutter asset path (used with [fromAsset]).
  final String? assetName;

  // ── Built-in defaults ──────────────────────────────────────

  /// The standard blue pin marker (default).
  static const SiroBitmap defaultMarker = SiroBitmap._(
    mapLibreImageId: 'siro-marker-default',
  );

  // Hue constants matching google_maps_flutter
  static const double hueRed = 0.0;
  static const double hueOrange = 30.0;
  static const double hueYellow = 60.0;
  static const double hueGreen = 120.0;
  static const double hueCyan = 180.0;
  static const double hueAzure = 210.0;
  static const double hueBlue = 240.0;
  static const double hueViolet = 270.0;
  static const double hueMagenta = 300.0;
  static const double hueRose = 330.0;

  /// A colored pin marker. [hue] is a value from 0–360 (HSV hue).
  ///
  /// Use the `hue*` constants (e.g. [SiroBitmap.hueBlue]) for clarity.
  static SiroBitmap defaultMarkerWithHue(double hue) {
    return SiroBitmap._(
      mapLibreImageId: 'siro-marker-hue-${hue.toInt()}',
      size: 1.0,
    );
  }

  // ── Custom bitmaps ─────────────────────────────────────────

  /// Load an icon from a Flutter asset bundle.
  ///
  /// ```dart
  /// icon: SiroBitmap.fromAsset('assets/icons/car.png')
  /// ```
  static SiroBitmap fromAsset(String assetName, {double? size}) {
    final sanitizedId = 'asset_${assetName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    return SiroBitmap._(
      mapLibreImageId: sanitizedId,
      assetName: assetName,
      size: size,
    );
  }

  /// Load an icon from an asset image configuration (google_maps_flutter compatibility).
  static Future<SiroBitmap> fromAssetImage(
    dynamic configuration,
    String assetName, {
    dynamic bundle,
    String? package,
    bool mipmaps = true,
  }) async {
    final fullName = package == null ? assetName : 'packages/$package/$assetName';
    return SiroBitmap.fromAsset(fullName);
  }

  /// Load an icon from raw image bytes (e.g. a network image you decoded).
  static SiroBitmap fromBytes(Uint8List bytes, {double? size}) {
    return SiroBitmap._(
      mapLibreImageId: 'bytes:${bytes.hashCode}',
      bytes: bytes,
      size: size,
    );
  }

  /// Reference an image already registered in the MapLibre style.
  ///
  /// Use this when your map style JSON already defines the sprite image.
  static SiroBitmap fromStyleImage(String imageId, {double? size}) {
    return SiroBitmap._(
      mapLibreImageId: imageId,
      size: size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiroBitmap &&
          runtimeType == other.runtimeType &&
          mapLibreImageId == other.mapLibreImageId &&
          size == other.size;

  @override
  int get hashCode => Object.hash(mapLibreImageId, size);

  @override
  String toString() => 'SiroBitmap($mapLibreImageId)';
}

/// Backward compatibility alias for developers migrating from `google_maps_flutter`.
typedef BitmapDescriptor = SiroBitmap;

