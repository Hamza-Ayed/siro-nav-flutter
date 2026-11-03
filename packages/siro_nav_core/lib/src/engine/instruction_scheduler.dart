import 'dart:math' as math;
import '../models/nav_step.dart';
import '../events/nav_events.dart';

enum InstructionStage {
  none,
  advance, // e.g. 500m - 1km out
  prepare, // e.g. 150m - 300m out
  immediate, // e.g. 0 - 30m out ("انعطف الآن")
}

/// Dynamic speed-based instruction scheduler.
/// Converts turn distance into time-to-maneuver to alert early on highways and accurately in city streets.
class InstructionScheduler {
  int _lastAnnouncedStepIndex = -1;
  InstructionStage _currentStage = InstructionStage.none;

  void reset() {
    _lastAnnouncedStepIndex = -1;
    _currentStage = InstructionStage.none;
  }

  /// Evaluates distance and speed to the upcoming maneuver and generates [InstructionEvent] if due.
  InstructionEvent? evaluate({
    required NavStep currentStep,
    required double distanceToStepMeters,
    required double speedKmh,
  }) {
    if (_lastAnnouncedStepIndex != currentStep.index) {
      _lastAnnouncedStepIndex = currentStep.index;
      _currentStage = InstructionStage.none;
    }

    // Convert speed to meters per second (minimum speed floor 5 m/s or 18 km/h to prevent division by zero)
    final double speedMps = math.max(5.0, speedKmh * (1000.0 / 3600.0));
    final double timeToTurnSeconds = distanceToStepMeters / speedMps;

    // Stage 3: Immediate maneuver (distance <= 30m OR time <= 3 seconds)
    if (distanceToStepMeters <= 30.0 ||
        (distanceToStepMeters < 50.0 && timeToTurnSeconds <= 3.5)) {
      if (_currentStage != InstructionStage.immediate) {
        _currentStage = InstructionStage.immediate;
        return InstructionEvent(
          stepIndex: currentStep.index,
          instruction: currentStep.instruction,
          streetName: currentStep.streetName,
          maneuverType: currentStep.maneuverType,
          exitNumber: currentStep.exitNumber,
          distanceMeters: distanceToStepMeters,
          timeSeconds: timeToTurnSeconds.round(),
          priority: 0, // High priority: immediate execution
          ttlSeconds: 6,
        );
      }
      return null;
    }

    // Stage 2: Preparation stage (time <= 12 seconds OR distance <= 180m on city streets)
    final double prepareDistThreshold = (speedKmh > 70.0) ? 350.0 : 180.0;
    if (distanceToStepMeters <= prepareDistThreshold &&
        timeToTurnSeconds <= 14.0) {
      if (_currentStage == InstructionStage.none ||
          _currentStage == InstructionStage.advance) {
        _currentStage = InstructionStage.prepare;
        return InstructionEvent(
          stepIndex: currentStep.index,
          instruction: currentStep.instruction,
          streetName: currentStep.streetName,
          maneuverType: currentStep.maneuverType,
          exitNumber: currentStep.exitNumber,
          distanceMeters: distanceToStepMeters,
          timeSeconds: timeToTurnSeconds.round(),
          priority: 2,
          ttlSeconds: 15,
        );
      }
      return null;
    }

    // Stage 1: Advance announcement (time <= 30 seconds OR distance between 500m and 1000m)
    final double advanceDistThreshold = (speedKmh > 80.0) ? 900.0 : 500.0;
    if (distanceToStepMeters <= advanceDistThreshold &&
        timeToTurnSeconds <= 35.0) {
      if (_currentStage == InstructionStage.none) {
        _currentStage = InstructionStage.advance;
        return InstructionEvent(
          stepIndex: currentStep.index,
          instruction: currentStep.instruction,
          streetName: currentStep.streetName,
          maneuverType: currentStep.maneuverType,
          exitNumber: currentStep.exitNumber,
          distanceMeters: distanceToStepMeters,
          timeSeconds: timeToTurnSeconds.round(),
          priority: 2,
          ttlSeconds: 25,
        );
      }
    }

    return null;
  }
}
