import 'dart:math' as math;

/// Configuration options for the Siro Navigation and Telemetry Engine.
class NavConfig {
  /// The Siro API Key required to authenticate against MapSaaS backend.
  /// Gated for monetization, licensing quotas, and tenant isolation.
  final String apiKey;

  /// Base URL of the Siro MapSaaS API (every route ends under `/api`).
  /// Default: the production gateway. Override it for staging or local tests.
  final String baseUrl;

  /// Anonymous device installation identifier.
  /// Auto-generated if not provided, ensuring privacy-by-design without requiring personal driver info.
  final String deviceId;

  /// Identifier telemetry is reported under (e.g. taxi captain ID or courier ID).
  /// Keep it stable for a device: keys provisioned per device accept telemetry
  /// from one id only and reject any other with HTTP 403.
  /// If omitted, [effectiveTrackerId] safely falls back to the anonymous [deviceId].
  final String? driverId;

  /// The active identifier used for telemetry probe grouping.
  String get effectiveTrackerId => driverId ?? deviceId;

  /// Sampling interval in seconds for recording GPS telemetry points while moving.
  final int telemetrySamplingIntervalSeconds;

  /// Interval in seconds for uploading telemetry batches to /telemetry/batch.
  final int telemetryUploadIntervalSeconds;

  /// Maximum points in a single upload batch.
  final int telemetryMaxBatchSize;

  /// Maximum points buffered locally when offline before dropping older points.
  final int telemetryMaxBufferSize;

  /// Off-route cross-track distance threshold in meters before triggering recalculation.
  final double offRouteThresholdMeters;

  /// Within this distance of the route the vehicle is drawn on the road (snapped).
  /// Farther away it is drawn at its real GPS position, for example inside a
  /// building or a car park before reaching the road. Separate from the reroute
  /// threshold, which is larger.
  final double snapToRouteMeters;

  /// Minimum time in seconds outside route before confirming off-route reroute.
  final int offRouteDebounceSeconds;

  /// Tolerance above speed limit before firing overspeed audio alert (e.g. +5 km/h).
  final double overspeedToleranceKmh;

  NavConfig({
    required this.apiKey,
    this.baseUrl = 'https://map-saas.intaleqapp.com/api',
    String? deviceId,
    this.driverId,
    this.telemetrySamplingIntervalSeconds = 3,
    this.telemetryUploadIntervalSeconds = 30,
    this.telemetryMaxBatchSize = 40,
    this.telemetryMaxBufferSize = 400,
    this.offRouteThresholdMeters = 55.0,
    this.offRouteDebounceSeconds = 2,
    this.snapToRouteMeters = 20.0,
    this.overspeedToleranceKmh = 5.0,
  }) : deviceId = deviceId ?? (_processDeviceId ??= _generateAnonymousDeviceId());

  /// One anonymous id per app run, so every trip of the run reports as one device.
  static String? _processDeviceId;

  /// Local shape check only; the server decides whether the key is valid.
  bool get isValidKey =>
      apiKey.trim().isNotEmpty && !RegExp(r'\s').hasMatch(apiKey.trim());

  static String _generateAnonymousDeviceId() {
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final randHex = List.generate(
            4, (_) => random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'))
        .join();
    return 'siro_dev_${timestamp}_$randHex';
  }
}
