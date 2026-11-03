import '../models/nav_point.dart';
import '../models/nav_route.dart';
import '../models/speed_camera.dart';

/// Base class for all navigation, guidance, telemetry, and security events emitted by the core.
abstract class NavEvent {
  final DateTime timestamp;
  NavEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

/// Emitted when a new guidance instruction should be presented or announced.
class InstructionEvent extends NavEvent {
  final int stepIndex;
  final String instruction;
  final String streetName;
  final int maneuverType;
  final int? exitNumber;
  final double distanceMeters;
  final int timeSeconds;
  final int
      priority; // 0: immediate turn, 1: camera, 2: advance notice, 3: informational
  final int ttlSeconds; // Time to live before expiration

  InstructionEvent({
    required this.stepIndex,
    required this.instruction,
    required this.streetName,
    required this.maneuverType,
    this.exitNumber,
    required this.distanceMeters,
    required this.timeSeconds,
    this.priority = 2,
    this.ttlSeconds = 15,
  });
}

/// Emitted on every location update with real-time navigation progress.
class ProgressEvent extends NavEvent {
  final NavPoint rawPosition;
  final NavPoint snappedPosition;
  final double distanceToNextManeuverMeters;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;
  final double currentSpeedKmh;
  final int currentStepIndex;
  final double progressFraction; // 0.0 to 1.0

  ProgressEvent({
    required this.rawPosition,
    required this.snappedPosition,
    required this.distanceToNextManeuverMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.currentSpeedKmh,
    required this.currentStepIndex,
    required this.progressFraction,
  });
}

/// Emitted when vehicle deviates beyond the off-route threshold.
class OffRouteEvent extends NavEvent {
  final NavPoint currentPosition;
  final double deviationMeters;
  final int offRouteDurationSeconds;

  OffRouteEvent({
    required this.currentPosition,
    required this.deviationMeters,
    required this.offRouteDurationSeconds,
  });
}

/// Emitted when dynamic rerouting is initiated.
class RerouteTriggeredEvent extends NavEvent {
  final NavPoint deviationPoint;
  final String reason;

  RerouteTriggeredEvent({
    required this.deviationPoint,
    this.reason = 'deviation_from_route',
  });
}

/// Emitted when a new route has replaced the old one.
class RerouteSuccessEvent extends NavEvent {
  final NavRoute newRoute;

  RerouteSuccessEvent({required this.newRoute});
}

/// Emitted when the destination is successfully reached.
class ArrivalEvent extends NavEvent {
  final NavPoint finalPosition;
  final double totalDistanceTraveledMeters;
  final int totalDurationSeconds;

  ArrivalEvent({
    required this.finalPosition,
    required this.totalDistanceTraveledMeters,
    required this.totalDurationSeconds,
  });
}

/// Emitted when approaching an active speed camera.
class SpeedCameraEvent extends NavEvent {
  final SpeedCamera camera;
  final double distanceMeters;

  SpeedCameraEvent({
    required this.camera,
    required this.distanceMeters,
  });
}

/// Emitted when vehicle speed exceeds the road limit plus tolerance.
class OverspeedAlertEvent extends NavEvent {
  final double currentSpeedKmh;
  final int speedLimitKmh;

  OverspeedAlertEvent({
    required this.currentSpeedKmh,
    required this.speedLimitKmh,
  });
}

/// Emitted during telemetry collection and periodic batch uploads.
class TelemetryBatchEvent extends NavEvent {
  final int batchCount;
  final int pendingBufferedCount;
  final bool uploaded;
  final String? errorMessage;

  TelemetryBatchEvent({
    required this.batchCount,
    required this.pendingBufferedCount,
    required this.uploaded,
    this.errorMessage,
  });
}

/// Security & Licensing Gate: Emitted when an API key is missing, unauthorized, or quota exceeded.
class AuthErrorEvent extends NavEvent {
  final String code;
  final String message;

  AuthErrorEvent({
    required this.code,
    required this.message,
  });
}

/// Emitted when GPS signal accuracy degrades or ceases.
class GpsSignalDegradedEvent extends NavEvent {
  final double currentAccuracyMeters;
  GpsSignalDegradedEvent({required this.currentAccuracyMeters});
}

/// Emitted when high-accuracy GPS signal is restored.
class GpsSignalRestoredEvent extends NavEvent {
  final double currentAccuracyMeters;
  GpsSignalRestoredEvent({required this.currentAccuracyMeters});
}
