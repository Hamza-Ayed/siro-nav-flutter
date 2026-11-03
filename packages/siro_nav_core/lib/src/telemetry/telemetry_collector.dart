import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nav_config.dart';
import '../models/nav_point.dart';
import '../models/telemetry_point.dart';
import '../events/nav_events.dart';

/// Telemetry probe and live fleet tracking engine.
/// Batches vehicle positions, buffers offline points, and streams batches to /telemetry/batch.
class TelemetryCollector {
  final NavConfig config;
  final http.Client _httpClient;
  final StreamController<NavEvent> _eventController;

  final List<TelemetryPoint> _buffer = [];
  DateTime? _lastSampleTime;
  DateTime? _lastFlushTime;
  NavPoint? _previousPoint;
  double _cumulativeDistanceMeters = 0.0;
  Timer? _periodicFlushTimer;
  bool _isFlushing = false;

  TelemetryCollector({
    required this.config,
    required StreamController<NavEvent> eventController,
    http.Client? httpClient,
  })  : _eventController = eventController,
        _httpClient = httpClient ?? http.Client();

  /// Total points currently queued in memory awaiting upload
  int get bufferedCount => _buffer.length;

  /// Cumulative distance recorded in this session
  double get cumulativeDistanceMeters => _cumulativeDistanceMeters;

  /// Starts the periodic flush timer based on config
  void start() {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = Timer.periodic(
      Duration(seconds: config.telemetryUploadIntervalSeconds),
      (_) => flush(),
    );
  }

  /// Ingests a new GPS point snapshot from navigation stream
  void recordPoint(NavPoint point) {
    final now = DateTime.now();

    // Cumulative distance calculation
    if (_previousPoint != null) {
      final delta = _previousPoint!.distanceTo(point);
      // Filter out GPS jump noise (>100 m/s is unrealistic for road vehicles)
      if (delta < 200.0) {
        _cumulativeDistanceMeters += delta;
      }
    }
    _previousPoint = point;

    // Check sampling interval
    if (_lastSampleTime != null) {
      final elapsed = now.difference(_lastSampleTime!).inSeconds;
      if (elapsed < config.telemetrySamplingIntervalSeconds) {
        return; // Skip sample to maintain battery and bandwidth economy
      }
    }
    _lastSampleTime = now;

    // Build telemetry snapshot
    final snapshot = TelemetryPoint(
      driverId: config.effectiveTrackerId,
      latitude: point.latitude,
      longitude: point.longitude,
      speed: point.speedKmh,
      heading: point.heading,
      elevation: point.altitude,
      distance: _cumulativeDistanceMeters,
      timestamp: point.timestamp,
    );

    // Buffer management with overflow protection
    if (_buffer.length >= config.telemetryMaxBufferSize) {
      _buffer.removeAt(0); // Evict oldest point to keep memory bound
    }
    _buffer.add(snapshot);

    // Immediate flush if batch size ceiling is hit
    if (_buffer.length >= config.telemetryMaxBatchSize) {
      flush();
    }
  }

  /// Flushes buffered telemetry points to Siro backend /telemetry/batch
  Future<bool> flush() async {
    if (_isFlushing || _buffer.isEmpty) return false;
    _isFlushing = true;

    // Take current slice to upload
    final batchCount = _buffer.length > config.telemetryMaxBatchSize
        ? config.telemetryMaxBatchSize
        : _buffer.length;
    final batch = _buffer.sublist(0, batchCount);

    try {
      final uri = Uri.parse('${config.baseUrl}/telemetry/batch');
      final payload = json.encode({
        'points': batch.map((p) => p.toJson()).toList(),
      });

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'x-api-key': config.apiKey,
              'Content-Type': 'application/json',
              'User-Agent': 'SiroNavCore-SDK/0.1.0',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Upload successful: remove batch from buffer
        _buffer.removeRange(0, batchCount);
        _lastFlushTime = DateTime.now();

        _emit(TelemetryBatchEvent(
          batchCount: batchCount,
          pendingBufferedCount: _buffer.length,
          uploaded: true,
        ));
        _isFlushing = false;
        return true;
      } else {
        _emit(TelemetryBatchEvent(
          batchCount: batchCount,
          pendingBufferedCount: _buffer.length,
          uploaded: false,
          errorMessage: 'Server rejected batch: HTTP ${response.statusCode}',
        ));
        _isFlushing = false;
        return false;
      }
    } catch (e) {
      // Network offline or timeout - keep buffer intact for next retry
      _emit(TelemetryBatchEvent(
        batchCount: batchCount,
        pendingBufferedCount: _buffer.length,
        uploaded: false,
        errorMessage: e.toString(),
      ));
      _isFlushing = false;
      return false;
    }
  }

  /// Stops timer and flushes any remaining points
  Future<void> stop() async {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = null;
    if (_buffer.isNotEmpty) {
      await flush();
    }
  }

  void dispose() {
    _periodicFlushTimer?.cancel();
    _httpClient.close();
  }

  /// A flush can finish after the engine was disposed. Emitting then would throw.
  void _emit(NavEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }
}
