import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:siro_map/siro_map.dart';

/// Adds the Siro Limestone icons (place badges and one-way arrows) to the map.
///
/// The Limestone style has no sprite: the Siro apps draw these SVGs at runtime
/// and add them after the style loads. Without them, places show no badge.
class NavStyleIcons {
  NavStyleIcons._();

  static const _dir = 'packages/siro_nav/assets/map_icons/';
  static Future<Map<String, Uint8List>>? _icons;

  /// Symbol layers of the Limestone style that draw these icons.
  static const _iconLayers = [
    'places-golden-tier1',
    'places-golden-tier2',
    'places-golden-labels',
    'places-golden-homes',
    'road-direction-arrows',
  ];

  /// Adds every icon the style references. Safe to call on each style load.
  static Future<void> addAll(SiroMapController controller) async {
    try {
      final icons = await (_icons ??= _render());
      for (final entry in icons.entries) {
        await controller.addImage(entry.key, entry.value);
      }
      // Tiles laid out before the images existed keep their symbols without
      // icons; toggling visibility makes MapLibre lay them out again.
      for (final id in _iconLayers) {
        try {
          await controller.setLayerVisibility(id, false);
          await controller.setLayerVisibility(id, true);
        } catch (_) {}
      }
    } catch (_) {
      _icons = null;
    }
  }

  static Future<Map<String, Uint8List>> _render() async {
    final out = <String, Uint8List>{};
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where((a) => a.startsWith(_dir) && a.endsWith('.svg'));
    final ratio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    for (final path in files) {
      final name = path.substring(_dir.length, path.length - 4);
      final info = await vg.loadPicture(SvgAssetLoader(path), null);
      final w = (info.size.width * ratio).ceil();
      final h = (info.size.height * ratio).ceil();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(ratio)
        ..drawPicture(info.picture);
      final image = await recorder.endRecording().toImage(w, h);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      info.picture.dispose();
      image.dispose();
      if (png != null) out[name] = png.buffer.asUint8List();
    }
    return out;
  }
}
