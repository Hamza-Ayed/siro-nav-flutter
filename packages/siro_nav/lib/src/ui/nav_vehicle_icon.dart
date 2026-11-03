import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Draws the navigation vehicle marker: a small white disc with a blue chevron
/// pointing up. It matches the Siro Maps vehicle arrow, so it looks native on
/// the map. The map rotates the image to the heading.
class NavVehicleIcon {
  NavVehicleIcon._();

  /// Siro Maps blue, the same color as the active route line.
  static const Color defaultColor = Color(0xFF0071E3);

  /// PNG bytes for `SiroMapController.addImage`.
  static Future<Uint8List> render({
    Color color = defaultColor,
    double size = 96,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    _paint(canvas, size, color);

    final pixels = size.round();
    final image = await recorder.endRecording().toImage(pixels, pixels);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not encode the navigation vehicle icon');
    }
    return data.buffer.asUint8List();
  }

  static void _paint(Canvas canvas, double size, Color color) {
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.44;

    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center.translate(0, 3), radius * 0.8, shadowPaint);

    canvas.drawCircle(center, radius * 0.8, Paint()..color = Colors.white);

    final arrow = Path()
      ..moveTo(center.dx, center.dy - radius * 0.62)
      ..lineTo(center.dx + radius * 0.5, center.dy + radius * 0.4)
      ..lineTo(center.dx, center.dy + radius * 0.16)
      ..lineTo(center.dx - radius * 0.5, center.dy + radius * 0.4)
      ..close();

    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final arrowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius * 0.5, center.dy),
        Offset(center.dx + radius * 0.5, center.dy),
        [dark, light],
      );
    canvas.drawPath(arrow, arrowPaint);
  }
}
