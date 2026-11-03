import 'dart:io';

/// Optional logging for field tests. Off by default; turn it on in a test
/// build to see each GPS fix, each map update, and follow-mode changes.
///
/// Lines go to the console and to `tmp/siro_nav.log` in the app container, so
/// they can be read off a device running a release build:
/// `xcrun devicectl device copy from --device <id> --domain-type appDataContainer
///  --domain-identifier <bundle id> --source tmp/siro_nav.log --destination .`
class NavDiagnostics {
  NavDiagnostics._();

  static bool enabled = false;

  static void log(String message) {
    if (!enabled) return;
    final line =
        '[SiroNav] ${DateTime.now().toIso8601String().substring(11, 23)} $message';
    // ignore: avoid_print
    print(line);
    try {
      File('${Directory.systemTemp.path}/siro_nav.log')
          .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
