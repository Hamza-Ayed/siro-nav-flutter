/// Single turn-by-turn navigation maneuver step along a route.
class NavStep {
  final int index;
  final String instruction;
  final String streetName;
  final int maneuverType; // GraphHopper / OSRM sign conventions
  final int? exitNumber; // Roundabout exit number (1, 2, 3...)
  final double distanceMeters;
  final double durationSeconds;
  final double lat;
  final double lng;
  final List<int> coordinateInterval; // [startIndex, endIndex] in polyline

  /// Steepest grade on this step, in percent (negative = downhill).
  final double? slopePercent;

  /// Steep-road warning the server attached to this step, if any.
  final String? slopeWarning;

  const NavStep({
    required this.index,
    required this.instruction,
    this.streetName = '',
    required this.maneuverType,
    this.exitNumber,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.lat,
    required this.lng,
    this.coordinateInterval = const [0, 0],
    this.slopePercent,
    this.slopeWarning,
  });

  factory NavStep.fromJson(Map<String, dynamic> json, int idx) {
    final interval = json['interval'];
    final intervalList = (interval is List && interval.length >= 2)
        ? [interval[0] as int, interval[1] as int]
        : const [0, 0];

    return NavStep(
      index: idx,
      instruction: json['text']?.toString() ?? '',
      streetName: json['street_name']?.toString() ?? '',
      maneuverType: (json['sign'] as num?)?.toInt() ??
          (json['modifier'] as num?)?.toInt() ??
          0,
      exitNumber: (json['exit_number'] as num?)?.toInt(),
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: ((json['time'] as num?)?.toDouble() ?? 0.0) / 1000.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      coordinateInterval: intervalList,
    );
  }
}
