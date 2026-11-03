import 'package:siro_nav_core/siro_nav_core.dart';

/// Fare rules for the trip meter. Set them per trip, to match the app's own tariff.
class NavFareConfig {
  /// Charged once at the start of the trip.
  final double baseFare;

  /// Charged per kilometre driven.
  final double perKilometer;

  /// Charged per minute the vehicle waits, below [waitingSpeedKmh].
  final double perWaitingMinute;

  /// Shown after each amount. Defaults to JOD.
  final String currency;

  /// Below this speed the vehicle counts as waiting.
  final double waitingSpeedKmh;

  const NavFareConfig({
    this.baseFare = 0,
    required this.perKilometer,
    required this.perWaitingMinute,
    this.currency = 'JOD',
    this.waitingSpeedKmh = 5,
  });
}

/// A snapshot of the meter, for display or for billing.
class NavTripTotals {
  final double distanceKm;
  final double waitingMinutes;
  final double fare;
  final String currency;

  const NavTripTotals({
    required this.distanceKm,
    required this.waitingMinutes,
    required this.fare,
    required this.currency,
  });

  /// The fare with two decimals and the currency, for example "4.50 JOD".
  String get fareLabel => '${fare.toStringAsFixed(2)} $currency';

  @override
  String toString() =>
      'NavTripTotals(distanceKm: ${distanceKm.toStringAsFixed(3)}, '
      'waitingMinutes: ${waitingMinutes.toStringAsFixed(2)}, fare: $fare $currency)';
}

/// Adds up distance and waiting time from GPS fixes, and prices them.
///
/// Distance comes from fixes that are accurate enough, with gaps longer than
/// [_maxGap] skipped, since the path during a gap is unknown. Jitter while
/// parked is not counted as distance.
class NavTripMeter {
  NavTripMeter(this.config);

  final NavFareConfig config;

  static const double _maxAccuracyMeters = 50;

  /// Movement is counted once the vehicle is this far from the last counted
  /// point. Small steps add up (slow traffic, walking); GPS jitter while
  /// parked stays below it and is not counted.
  static const double _countStepMeters = 10;
  static const Duration _maxGap = Duration(seconds: 30);

  /// The last point distance was counted from.
  NavPoint? _anchor;

  /// The previous accepted fix, for elapsed time.
  NavPoint? _last;
  double _distanceMeters = 0;
  double _waitingSeconds = 0;

  /// Feeds one fix and returns the totals after it.
  NavTripTotals addFix(NavPoint fix) {
    if (fix.accuracy > _maxAccuracyMeters) return totals;

    final last = _last;
    _last = fix;
    final anchor = _anchor;
    if (last == null || anchor == null) {
      _anchor = fix;
      return totals;
    }

    final elapsed = fix.timestamp.difference(last.timestamp);
    if (elapsed <= Duration.zero) return totals;
    if (elapsed > _maxGap) {
      // The path during a long gap is unknown: restart from here.
      _anchor = fix;
      return totals;
    }

    final moved = anchor.distanceTo(fix);
    if (moved >= _countStepMeters) {
      _distanceMeters += moved;
      _anchor = fix;
    } else if (fix.speedKmh < config.waitingSpeedKmh) {
      _waitingSeconds += elapsed.inMilliseconds / 1000;
    }
    return totals;
  }

  NavTripTotals get totals {
    final km = _distanceMeters / 1000;
    final minutes = _waitingSeconds / 60;
    return NavTripTotals(
      distanceKm: km,
      waitingMinutes: minutes,
      fare: config.baseFare +
          config.perKilometer * km +
          config.perWaitingMinute * minutes,
      currency: config.currency,
    );
  }
}
