import '../billing/nav_trip_meter.dart';

/// Which leg of a ride-hailing or delivery job a trip is.
enum NavTripPhase {
  /// From the driver to the rider or the pickup point. Usually not charged.
  pickup,

  /// From the rider or the pickup point to the destination.
  trip;

  /// Arabic label for the screen.
  String get labelAr => this == NavTripPhase.pickup ? 'إلى الراكب' : 'الرحلة';
}

/// What happened on a trip, kept after it ends so the app can bill or log it.
class NavTripSummary {
  final NavTripPhase phase;
  final DateTime startedAt;
  final DateTime endedAt;

  /// True when the trip ended by reaching the destination, false when stopped.
  final bool arrived;

  /// Distance, waiting time and fare. Null when the trip had no fare config.
  final NavTripTotals? totals;

  const NavTripSummary({
    required this.phase,
    required this.startedAt,
    required this.endedAt,
    required this.arrived,
    this.totals,
  });

  Duration get duration => endedAt.difference(startedAt);
}
