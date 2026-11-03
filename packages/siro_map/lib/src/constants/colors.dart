// وظيفة الملف: تنفيذ أو إعداد colors ضمن هذا الجزء من المشروع.
import 'dart:ui' show Color;

/// Siro brand color palette.
///
/// CSS hex strings are provided for use with MapLibre layer properties.
/// Flutter [Color] constants are provided for use in Dart/Flutter code.
class SiroColors {
  SiroColors._();

  // ── Flutter Color constants ────────────────────────────────

  /// Primary Siro blue.
  static const Color primaryBlue = Color(0xFF0D47A1);

  /// Cyan for active / remaining route lines.
  static const Color routeCyan = Color(0xFF00E5FF);

  /// Soft gray for traveled paths or alternative routes.
  static const Color softGray = Color(0xFFBDBDBD);

  /// Semi-transparent gray for polygon fills (20 % opacity).
  static const Color fillGray = Color(0x33BDBDBD);

  /// Red for error or stop states.
  static const Color alertRed = Color(0xFFBA1A1A);

  // ── MapLibre hex strings ───────────────────────────────────

  static const String primaryBlueHex = '#0D47A1';
  static const String routeCyanHex = '#00e5ff';
  static const String softGrayHex = '#BDBDBD';
  static const String fillGrayHex = '#BDBDBD33';
  static const String alertRedHex = '#ba1a1a';
}
