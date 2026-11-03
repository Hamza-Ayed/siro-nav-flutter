/// Everything the Siro route API returns beyond geometry and turns: names,
/// traffic, fuel, terrain and speed limits. Read straight from `/api/maps/route`.
class NavRouteDetails {
  /// Route label, for example "عبر شارع الملكة رانيا".
  final String routeName;

  /// FASTEST, SHORTEST, ECO_FRIENDLY, ALTERNATIVE.
  final List<String> tags;

  final String? startName;
  final String? endName;

  /// Duration factor from traffic (1.0 = free flow).
  final double trafficFactor;

  /// Share of the route covered by live traffic data (0..1).
  final double liveTrafficCoverage;

  final NavFuelEstimate? fuel;
  final NavElevationSummary? elevation;

  /// Traffic level per stretch of the route, with the color to draw it in.
  final List<NavCongestionSegment> congestion;

  /// Posted speed limits per stretch of the route.
  final List<NavSpeedLimitSegment> speedLimits;

  /// The full response, for fields this class does not model.
  final Map<String, dynamic> raw;

  const NavRouteDetails({
    required this.routeName,
    this.tags = const [],
    this.startName,
    this.endName,
    this.trafficFactor = 1.0,
    this.liveTrafficCoverage = 0,
    this.fuel,
    this.elevation,
    this.congestion = const [],
    this.speedLimits = const [],
    this.raw = const {},
  });

  factory NavRouteDetails.fromJson(Map<String, dynamic> json) {
    final eco = json['ecoMetrics'];
    final elev = json['elevationSummary'];
    final live = json['liveTraffic'];
    return NavRouteDetails(
      routeName: json['routeName']?.toString() ?? '',
      tags:
          (json['tags'] as List? ?? const []).map((t) => t.toString()).toList(),
      startName: json['startName']?.toString(),
      endName: json['endName']?.toString(),
      trafficFactor: _num(json['trafficFactor']) ?? 1.0,
      liveTrafficCoverage: live is Map ? (_num(live['coverage']) ?? 0) : 0,
      fuel: eco is Map<String, dynamic> ? NavFuelEstimate.fromJson(eco) : null,
      elevation: elev is Map<String, dynamic>
          ? NavElevationSummary.fromJson(elev)
          : null,
      congestion: [
        for (final s in json['congestionSegments'] as List? ?? const [])
          if (s is Map<String, dynamic>) NavCongestionSegment.fromJson(s),
      ],
      speedLimits: [
        for (final s in json['speedLimits'] as List? ?? const [])
          if (s is Map<String, dynamic>) NavSpeedLimitSegment.fromJson(s),
      ],
      raw: json,
    );
  }

  /// The posted limit at polyline index [index], or null when unknown.
  int? speedLimitAt(int index) {
    for (final s in speedLimits) {
      if (index >= s.startIndex && index <= s.endIndex) return s.kmh;
    }
    return null;
  }
}

/// Fuel, energy and emissions for the route, priced with the country tariff.
class NavFuelEstimate {
  final double gasolineLiters;
  final double cost;
  final String currency;
  final String costLabel;
  final double evKWh;
  final double evCost;
  final double co2Kg;
  final int trafficDelayMinutes;
  final int ecoScore;
  final String? ecoBadge;
  final String? terrainDifficulty;
  final String? mechanicalAdvice;

  const NavFuelEstimate({
    required this.gasolineLiters,
    required this.cost,
    required this.currency,
    required this.costLabel,
    this.evKWh = 0,
    this.evCost = 0,
    this.co2Kg = 0,
    this.trafficDelayMinutes = 0,
    this.ecoScore = 0,
    this.ecoBadge,
    this.terrainDifficulty,
    this.mechanicalAdvice,
  });

  factory NavFuelEstimate.fromJson(Map<String, dynamic> json) =>
      NavFuelEstimate(
        gasolineLiters: _num(json['estimatedGasolineLiters']) ?? 0,
        cost: _num(json['estimatedCost']) ?? 0,
        currency: json['currency']?.toString() ?? '',
        costLabel: json['estimatedCostFormatted']?.toString() ?? '',
        evKWh: _num(json['estimatedEvKWh']) ?? 0,
        evCost: _num(json['estimatedEvCost']) ?? 0,
        co2Kg: _num(json['co2Kg']) ?? 0,
        trafficDelayMinutes: (_num(json['trafficDelayMinutes']) ?? 0).round(),
        ecoScore: (_num(json['ecoScore']) ?? 0).round(),
        ecoBadge: json['ecoBadge']?.toString(),
        terrainDifficulty: json['terrainDifficulty']?.toString(),
        mechanicalAdvice: json['mechanicalAdvice']?.toString(),
      );
}

/// Climbs, descents and steep stretches along the route.
class NavElevationSummary {
  final double totalAscentMeters;
  final double totalDescentMeters;
  final double maxInclinePercent;
  final double maxDeclinePercent;
  final List<NavSteepStretch> steepStretches;

  const NavElevationSummary({
    required this.totalAscentMeters,
    required this.totalDescentMeters,
    required this.maxInclinePercent,
    required this.maxDeclinePercent,
    this.steepStretches = const [],
  });

  factory NavElevationSummary.fromJson(Map<String, dynamic> json) =>
      NavElevationSummary(
        totalAscentMeters: _num(json['totalAscentMeters']) ?? 0,
        totalDescentMeters: _num(json['totalDescentMeters']) ?? 0,
        maxInclinePercent: _num(json['maxInclinePercent']) ?? 0,
        maxDeclinePercent: _num(json['maxDeclinePercent']) ?? 0,
        steepStretches: [
          for (final w in json['steepWarnings'] as List? ?? const [])
            if (w is Map<String, dynamic>) NavSteepStretch.fromJson(w),
        ],
      );
}

/// One steep climb or descent, with the warning text the server wrote.
class NavSteepStretch {
  final String text;
  final double slopePercent;
  final double lengthMeters;
  final int startIndex;
  final int endIndex;

  const NavSteepStretch({
    required this.text,
    required this.slopePercent,
    required this.lengthMeters,
    required this.startIndex,
    required this.endIndex,
  });

  bool get isClimb => slopePercent > 0;

  factory NavSteepStretch.fromJson(Map<String, dynamic> json) =>
      NavSteepStretch(
        text: json['text']?.toString() ?? '',
        slopePercent: _num(json['slopePercent']) ?? 0,
        lengthMeters: _num(json['lengthM']) ?? 0,
        startIndex: (_num(json['startIndex']) ?? 0).round(),
        endIndex: (_num(json['endIndex']) ?? 0).round(),
      );
}

/// Traffic on one stretch of the route: normal, moderate or heavy.
class NavCongestionSegment {
  final int startIndex;
  final int endIndex;
  final String level;

  /// Hex color the server picks for this level, for example "#ef4444".
  final String color;
  final double factor;

  const NavCongestionSegment({
    required this.startIndex,
    required this.endIndex,
    required this.level,
    required this.color,
    required this.factor,
  });

  factory NavCongestionSegment.fromJson(Map<String, dynamic> json) =>
      NavCongestionSegment(
        startIndex: (_num(json['startIndex']) ?? 0).round(),
        endIndex: (_num(json['endIndex']) ?? 0).round(),
        level: json['level']?.toString() ?? 'normal',
        color: json['color']?.toString() ?? '#22c55e',
        factor: _num(json['factor']) ?? 1,
      );
}

/// A posted speed limit over a stretch of the route.
class NavSpeedLimitSegment {
  final int startIndex;
  final int endIndex;
  final int kmh;

  const NavSpeedLimitSegment({
    required this.startIndex,
    required this.endIndex,
    required this.kmh,
  });

  factory NavSpeedLimitSegment.fromJson(Map<String, dynamic> json) =>
      NavSpeedLimitSegment(
        startIndex: (_num(json['startIndex']) ?? 0).round(),
        endIndex: (_num(json['endIndex']) ?? 0).round(),
        kmh: (_num(json['kmh']) ?? 0).round(),
      );
}

double? _num(Object? v) => v is num ? v.toDouble() : null;
