// وظيفة الملف: واجهة التصدير الرسمية لحزمة siro_map
/// Siro Maps SDK for Flutter.
///
/// A Google Maps Flutter-compatible API backed by MapLibre GL,
/// optimized for Jordan, Syria, and the broader MENA region.
library siro_map;

// Re-export core MapLibre primitives under familiar names
export 'package:maplibre_gl/maplibre_gl.dart'
    show
        LatLng,
        LatLngBounds,
        OfflineRegion,
        OfflineRegionDefinition,
        downloadOfflineRegion,
        getListOfRegions,
        deleteOfflineRegion,
        MyLocationRenderMode,
        MyLocationTrackingMode;

// Public SDK surface
export 'src/siro_map_widget.dart';
export 'src/siro_map_controller.dart';
export 'src/siro_3d_map.dart';
export 'src/styles.dart';
export 'src/offline_service.dart';
export 'src/telemetry_service.dart';
export 'src/constants/colors.dart';
export 'src/utils/polyline_utils.dart';

// Models — mirrors google_maps_flutter public types
export 'src/models/geometry.dart';
export 'src/models/bitmap.dart';
export 'src/models/info_window.dart';
export 'src/models/types.dart';
