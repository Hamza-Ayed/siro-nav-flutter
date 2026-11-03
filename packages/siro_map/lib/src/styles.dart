// وظيفة الملف: تنفيذ أو إعداد styles ضمن هذا الجزء من المشروع.
/// Predefined Siro Map tile style URLs.
class SiroStyles {
  SiroStyles._();

  /// Dark premium Obsidian style — the Siro default.
  ///
  /// This style is optimized for readability and a premium look.
  static String obsidian(String apiKey) =>
      'https://map-saas.intaleqapp.com/api/maps/style.json?theme=obsidian&api_key=$apiKey';

  /// High-contrast light style.
  ///
  /// Best for daylight use and printing.
  static String light(String apiKey) =>
      'https://map-saas.intaleqapp.com/api/maps/style.json?theme=light&api_key=$apiKey';

  /// Satellite imagery with road labels.
  ///
  /// High-resolution satellite tiles overlaid with Siro vector labels.
  static String satellite(String apiKey) =>
      'https://map-saas.intaleqapp.com/api/maps/style.json?theme=satellite&api_key=$apiKey';

  /// Path to the local light style asset.
  static const String localLight = 'assets/style.json';

  /// Path to the local dark style asset.
  static const String localDark = 'assets/style_dark.json';

  /// Path to the local ESRI satellite hybrid style asset.
  static const String localSatellite = 'assets/style-satellite.json';

  /// Path to the sovereign tactical military style asset with rock escarpments, berms, and cliffs.
  static const String localTactical = 'assets/tactical-style.json';

  /// Sovereign 100% Offline Tactical / Military Style (Defaults to Tactical Style with Obstacles)
  /// التصميم التكتيكي والعسكري مع طبقات الموانع الصخرية والجدران والخنادق
  static String offlineTactical({String localStylePath = 'assets/tactical-style.json'}) =>
      localStylePath.startsWith('assets/') || localStylePath.startsWith('asset://')
          ? (localStylePath.startsWith('asset://') ? localStylePath : 'asset://$localStylePath')
          : (localStylePath.startsWith('file://') ? localStylePath : 'file://$localStylePath');

  /// Local on-device file style
  /// تحميل ملف تصميم مخصص من ذاكرة الجهاز المحلية
  static String localFile(String absoluteFilePath) =>
      absoluteFilePath.startsWith('file://') ? absoluteFilePath : 'file://$absoluteFilePath';
}
