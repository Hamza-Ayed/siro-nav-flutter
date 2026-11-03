// وظيفة الملف: اختبارات محرك التتبع، تغطي نبضة الوقوف وفلتر السكون وتغيّر حالة الوقوف وبوابة الموافقة والمعرّف.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siro_map/src/telemetry_service.dart';

void main() {
  final service = SiroTelemetryService.instance;
  final t0 = DateTime.utc(2026, 10, 23, 12);

  setUp(() {
    service.resetForTesting();
    service.initialize(apiKey: 'test-key', installId: 'test-install');
  });

  tearDown(() {
    service.resetForTesting();
  });

  test('stationary device records a heartbeat every 30s without new GPS events', () {
    // أول قراءة تُسجَّل
    expect(
      service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 0, heading: 0, now: t0),
      isTrue,
    );

    // بعد 5 ثوانٍ وهو واقف: لا تُسجَّل نقطة
    expect(
      service.recordPosition(
        latitude: 32.1,
        longitude: 36.1,
        speedKmH: 0,
        heading: 0,
        now: t0.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(service.isStationary, isTrue);

    // بدون أي قراءة GPS جديدة: النبضة تُسجَّل بعد 30 ثانية
    expect(service.recordHeartbeat(now: t0.add(const Duration(seconds: 10))), isFalse);
    expect(service.recordHeartbeat(now: t0.add(const Duration(seconds: 31))), isTrue);
    expect(service.bufferedPointCount, 2);

    // النبضة التالية بعد 30 ثانية أخرى من آخر نبضة
    expect(service.recordHeartbeat(now: t0.add(const Duration(seconds: 45))), isFalse);
    expect(service.recordHeartbeat(now: t0.add(const Duration(seconds: 62))), isTrue);
    expect(service.bufferedPointCount, 3);
  });

  test('moving device does not produce heartbeats', () {
    service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0);
    expect(service.isStationary, isFalse);
    expect(
      service.recordHeartbeat(now: t0.add(const Duration(seconds: 60))),
      isFalse,
    );
    expect(service.bufferedPointCount, 1);
  });

  test('moving samples are recorded every 3 seconds', () {
    service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0);
    expect(
      service.recordPosition(
        latitude: 32.1001,
        longitude: 36.1,
        speedKmH: 40,
        heading: 90,
        now: t0.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      service.recordPosition(
        latitude: 32.1002,
        longitude: 36.1,
        speedKmH: 40,
        heading: 90,
        now: t0.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
  });

  test('stationaryChanges emits only when the state changes', () async {
    final events = <bool>[];
    final sub = service.stationaryChanges.listen(events.add);

    service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 0, heading: 0, now: t0);
    service.recordPosition(
      latitude: 32.1,
      longitude: 36.1,
      speedKmH: 0,
      heading: 0,
      now: t0.add(const Duration(seconds: 5)),
    );
    service.recordPosition(
      latitude: 32.1005,
      longitude: 36.1,
      speedKmH: 30,
      heading: 0,
      now: t0.add(const Duration(seconds: 10)),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // الحالة بدأت متحركة (افتراضياً false)، ثم وقفت، ثم تحركت
    expect(events, [true, false]);
  });

  test('nothing is recorded while collection is disabled', () {
    service.setEnabled(false);
    expect(service.isEnabled, isFalse);
    expect(
      service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0),
      isFalse,
    );
    expect(service.recordHeartbeat(now: t0.add(const Duration(seconds: 60))), isFalse);
    expect(service.bufferedPointCount, 0);
  });

  test('disabling collection drops points that were not sent yet', () {
    service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0);
    expect(service.bufferedPointCount, 1);

    service.setEnabled(false);
    expect(service.bufferedPointCount, 0);
  });

  test('points carry the install id as driver_id', () {
    service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0);
    expect(service.bufferedPoints.single.driverId, 'test-install');
  });

  test('initialize enables telemetry by default without requiring explicit consent parameter', () {
    service.initialize(apiKey: 'test-key', installId: 'test-install');
    expect(service.isEnabled, isTrue);
    expect(
      service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0),
      isTrue,
    );
  });

  test('explicitly passing consentGranted false disables collection', () {
    service.initialize(apiKey: 'test-key', installId: 'test-install', consentGranted: false);
    expect(service.isEnabled, isFalse);
    expect(
      service.recordPosition(latitude: 32.1, longitude: 36.1, speedKmH: 40, heading: 90, now: t0),
      isFalse,
    );
  });

  test('generateInstallId returns a random RFC 4122 version 4 UUID', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final first = SiroTelemetryService.generateInstallId();
    final second = SiroTelemetryService.generateInstallId();

    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(first, isNot(second));
  });

  test('loadOrCreateInstallId keeps the same id until storage is cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await SiroTelemetryService.loadOrCreateInstallId();
    expect(await SiroTelemetryService.loadOrCreateInstallId(), first);

    SharedPreferences.setMockInitialValues({});
    expect(await SiroTelemetryService.loadOrCreateInstallId(), isNot(first));
  });
}
