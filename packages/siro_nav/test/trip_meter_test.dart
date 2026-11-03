import 'package:flutter_test/flutter_test.dart';
import 'package:siro_nav/siro_nav.dart';

NavPoint _fix(double lat, double lng, DateTime at,
    {double speed = 40, double accuracy = 5}) {
  return NavPoint(
    latitude: lat,
    longitude: lng,
    speedKmh: speed,
    accuracy: accuracy,
    timestamp: at,
  );
}

void main() {
  const config = NavFareConfig(
    baseFare: 0.5,
    perKilometer: 0.35,
    perWaitingMinute: 0.05,
  );
  final start = DateTime(2026, 11, 3, 10);

  test('counts driven distance from moving fixes', () {
    final meter = NavTripMeter(config);
    // About 1.1 km north, one fix per second at 40 km/h.
    var lat = 31.9;
    meter.addFix(_fix(lat, 35.9, start));
    for (var i = 1; i <= 20; i++) {
      lat += 0.0005; // about 55 m per step
      meter.addFix(_fix(lat, 35.9, start.add(Duration(seconds: i))));
    }

    final totals = meter.totals;
    expect(totals.distanceKm, closeTo(1.1, 0.05));
    expect(totals.waitingMinutes, closeTo(0, 1e-9));
  });

  test('parked time counts as waiting, and jitter is not distance', () {
    final meter = NavTripMeter(config);
    meter.addFix(_fix(31.9, 35.9, start, speed: 0));
    // Sixty seconds parked, with a 2 m jitter on each fix.
    for (var i = 1; i <= 60; i++) {
      final jitter = i.isEven ? 0.00002 : 0.0;
      meter.addFix(
          _fix(31.9 + jitter, 35.9, start.add(Duration(seconds: i)), speed: 0));
    }

    final totals = meter.totals;
    expect(totals.waitingMinutes, closeTo(1.0, 0.02));
    expect(totals.distanceKm, closeTo(0, 0.001));
  });

  test('a gap longer than 30 seconds adds no distance', () {
    final meter = NavTripMeter(config);
    meter.addFix(_fix(31.9, 35.9, start));
    // Back after 5 minutes, 5 km away: the path in between is unknown.
    meter.addFix(_fix(31.945, 35.9, start.add(const Duration(minutes: 5))));

    expect(meter.totals.distanceKm, closeTo(0, 1e-9));
  });

  test('inaccurate fixes are ignored', () {
    final meter = NavTripMeter(config);
    meter.addFix(_fix(31.9, 35.9, start));
    meter.addFix(_fix(31.95, 35.9, start.add(const Duration(seconds: 1)),
        accuracy: 120));

    expect(meter.totals.distanceKm, closeTo(0, 1e-9));
  });

  test('the fare is the base plus distance and waiting charges', () {
    final meter = NavTripMeter(config);
    final totals = NavTripTotals(
      distanceKm: 4,
      waitingMinutes: 2,
      fare: config.baseFare +
          config.perKilometer * 4 +
          config.perWaitingMinute * 2,
      currency: config.currency,
    );

    expect(totals.fare, closeTo(0.5 + 1.4 + 0.1, 1e-9));
    expect(totals.fareLabel, '2.00 JOD');
    expect(meter.totals.fare, closeTo(config.baseFare, 1e-9));
  });

  test('slow movement in small steps still adds up to distance', () {
    final meter = NavTripMeter(config);
    // 100 m north in 4 m steps, one every 3 seconds, at walking speed.
    var lat = 31.9;
    meter.addFix(_fix(lat, 35.9, start, speed: 4));
    for (var i = 1; i <= 25; i++) {
      lat += 0.000036; // about 4 m
      meter.addFix(
          _fix(lat, 35.9, start.add(Duration(seconds: 3 * i)), speed: 4));
    }
    expect(meter.totals.distanceKm, closeTo(0.1, 0.012));
  });
}
