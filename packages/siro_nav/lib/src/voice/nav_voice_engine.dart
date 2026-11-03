import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:siro_nav_core/siro_nav_core.dart';
import 'nav_voice_catalog.dart';

/// Interface for audio output playback (allows swapping mock, asset-player, or platform audio).
abstract class NavAudioOutput {
  Future<void> playAsset(String assetPath);
  Future<void> stop();
  void dispose();
}

/// Production hardware audio output using audioplayers (handles ducking & native speakers).
///
/// Package clips are copied once to the temp directory and played as device
/// files. Two alternatives fail on iOS in audioplayers 6.x: `AssetSource` does
/// not resolve package assets, and `BytesSource` is not implemented on iOS.
class DeviceAudioOutput implements NavAudioOutput {
  static const Duration _maxClipDuration = Duration(seconds: 8);

  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _clipFiles = {};

  DeviceAudioOutput() {
    _player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.duckOthers,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.assistanceNavigationGuidance,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
  }

  @override
  Future<void> playAsset(String assetPath) async {
    try {
      final filePath = _clipFiles[assetPath] ?? await _writeClip(assetPath);
      await _player.stop();
      // Subscribe before playing so a short clip cannot finish unnoticed.
      final finished = _player.onPlayerComplete.first;
      await _player.play(DeviceFileSource(filePath));
      try {
        await finished.timeout(_maxClipDuration);
      } on TimeoutException {
        await _player.stop();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DeviceAudioOutput] Playback error for $assetPath: $e');
      }
    }
  }

  Future<String> _writeClip(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = Directory('${Directory.systemTemp.path}/siro_nav_voice');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    _clipFiles[assetPath] = file.path;
    return file.path;
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
  }
}

/// Headless in-memory audio output for unit tests.
class LoggingAudioOutput implements NavAudioOutput {
  String? lastPlayedAsset;

  @override
  Future<void> playAsset(String assetPath) async {
    lastPlayedAsset = assetPath;
    if (kDebugMode) {
      debugPrint('[SiroVoiceEngine] Playing: $assetPath');
    }
  }

  @override
  Future<void> stop() async {
    lastPlayedAsset = null;
  }

  @override
  void dispose() {}
}

/// Priority-based voice instruction item.
class VoiceQueueItem {
  final String promptId;
  final String assetPath;
  final int
      priority; // 0: Immediate turn, 1: Camera/Safety, 2: Advance/Prep, 3: Informational
  final DateTime createdAt;
  final int ttlSeconds;

  VoiceQueueItem({
    required this.promptId,
    required this.assetPath,
    required this.priority,
    required this.ttlSeconds,
  }) : createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt).inSeconds > ttlSeconds;
}

/// Complete Voice Guidance Engine for Siro Nav.
/// Orchestrates priority queueing, message TTL expiration, instruction quantization,
/// and instant offline asset resolution.
class NavVoiceEngine {
  final NavVoiceCatalog catalog;
  final NavAudioOutput audioOutput;

  bool _isMuted = false;
  bool _isPlaying = false;
  VoiceQueueItem? _currentItem;
  final List<VoiceQueueItem> _queue = [];

  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;

  NavVoiceEngine({
    required this.catalog,
    NavAudioOutput? audioOutput,
  }) : audioOutput = audioOutput ?? DeviceAudioOutput();

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  /// Maps a navigation maneuver and distance to the optimal pre-baked voice prompt.
  String? resolvePromptId({
    required int maneuverType,
    required double distanceMeters,
    required int priority,
    int? exitNumber,
  }) {
    // 1. Immediate maneuvers (<= 35m)
    if (distanceMeters <= 35.0 || priority == 0) {
      return _resolveImmediatePrompt(maneuverType, exitNumber);
    }

    // 2. Quantized distance bins
    if (distanceMeters <= 60.0) {
      if (maneuverType == 2 || maneuverType == 3) return 'after_50m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_50m_turn_left';
      if (maneuverType == -6 || maneuverType == 6)
        return 'after_50m_roundabout';
      return null;
    }

    if (distanceMeters <= 125.0) {
      if (maneuverType == 2 || maneuverType == 3)
        return 'after_100m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_100m_turn_left';
      if (maneuverType == 8 || maneuverType == -8 || maneuverType == -98)
        return 'after_100m_u_turn';
      return null;
    }

    if (distanceMeters <= 175.0) {
      if (maneuverType == 2 || maneuverType == 3)
        return 'after_150m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_150m_turn_left';
      return null;
    }

    if (distanceMeters <= 225.0) {
      if (maneuverType == 2 || maneuverType == 3)
        return 'after_200m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_200m_turn_left';
      return null;
    }

    if (distanceMeters <= 350.0) {
      if (maneuverType == 2 || maneuverType == 3)
        return 'after_300m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_300m_turn_left';
      if (maneuverType == -6 || maneuverType == 6)
        return 'after_300m_roundabout';
      return null;
    }

    if (distanceMeters <= 600.0) {
      if (maneuverType == 2 || maneuverType == 3)
        return 'after_500m_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_500m_turn_left';
      if (maneuverType == -6 || maneuverType == 6)
        return 'after_500m_roundabout';
      if (maneuverType == 4 || maneuverType == 5) return 'after_500m_exit';
      return null;
    }

    if (distanceMeters <= 1200.0) {
      if (maneuverType == 2 || maneuverType == 3) return 'after_1km_turn_right';
      if (maneuverType == -2 || maneuverType == -3)
        return 'after_1km_turn_left';
      if (maneuverType == 4 || maneuverType == 5) return 'after_1km_exit';
      return null;
    }

    return null;
  }

  String _resolveImmediatePrompt(int maneuverType, int? exitNumber) {
    switch (maneuverType) {
      case 2: // Right
        return 'turn_right_now';
      case -2: // Left
        return 'turn_left_now';
      case 1: // Slight right
        return 'slight_right_now';
      case -1: // Slight left
        return 'slight_left_now';
      case 3: // Sharp right
        return 'sharp_right_now';
      case -3: // Sharp left
        return 'sharp_left_now';
      case 7: // Keep right
        return 'keep_right';
      case -7: // Keep left
        return 'keep_left';
      case 8:
      case -8:
      case -98: // U-turn
        return 'u_turn_now';
      case 4:
      case 5: // Exit
        return 'take_exit_now';
      case 6:
      case -6: // Roundabout
        if (exitNumber != null && exitNumber >= 1 && exitNumber <= 6) {
          return 'roundabout_exit_$exitNumber';
        }
        return 'enter_roundabout_now';
      default:
        return 'turn_right_now';
    }
  }

  /// Dispatches an event directly from navigation engine to voice announcement.
  Future<void> handleNavEvent(NavEvent event) async {
    if (_isMuted) return;

    if (event is InstructionEvent) {
      final promptId = resolvePromptId(
        maneuverType: event.maneuverType,
        distanceMeters: event.distanceMeters,
        priority: event.priority,
        exitNumber: event.exitNumber,
      );

      if (promptId != null) {
        await queuePrompt(promptId,
            priority: event.priority, ttlSeconds: event.ttlSeconds);
      }
    } else if (event is SpeedCameraEvent) {
      // A limit of 0 means unknown: announce the camera without a number.
      final limit = event.camera.speedLimitKmh;
      final promptId = limit > 0 ? 'camera_speed_$limit' : 'camera_ahead';
      await queuePrompt(
        catalog.hasPrompt(promptId) ? promptId : 'camera_ahead',
        priority: 1,
        ttlSeconds: 12,
      );
    } else if (event is OverspeedAlertEvent) {
      await queuePrompt('speed_warning', priority: 1, ttlSeconds: 8);
    } else if (event is RerouteTriggeredEvent) {
      await queuePrompt('rerouting', priority: 3, ttlSeconds: 10);
    } else if (event is RerouteSuccessEvent) {
      await queuePrompt('route_updated', priority: 3, ttlSeconds: 10);
    } else if (event is ArrivalEvent) {
      await queuePrompt('arrived_successfully', priority: 0, ttlSeconds: 30);
    }
  }

  /// Queues a prompt with priority preemption.
  Future<void> queuePrompt(
    String promptId, {
    int priority = 2,
    int ttlSeconds = 15,
  }) async {
    final assetPath = catalog.getAudioPath(promptId);
    if (assetPath == null) return;

    final item = VoiceQueueItem(
      promptId: promptId,
      assetPath: assetPath,
      priority: priority,
      ttlSeconds: ttlSeconds,
    );

    // P0 preempts any lower-priority speaking audio immediately
    if (priority == 0 && _currentItem != null && _currentItem!.priority > 0) {
      await audioOutput.stop();
      _isPlaying = false;
    }

    _queue.add(item);
    _queue.sort((a, b) => a.priority.compareTo(b.priority));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isPlaying || _isMuted || _queue.isEmpty) return;

    // Purge expired items
    _queue.removeWhere((item) => item.isExpired);
    if (_queue.isEmpty) return;

    final nextItem = _queue.removeAt(0);
    _currentItem = nextItem;
    _isPlaying = true;

    try {
      await audioOutput.playAsset(nextItem.assetPath);
    } finally {
      _isPlaying = false;
      _currentItem = null;
      if (_queue.isNotEmpty) {
        _processQueue();
      }
    }
  }

  Future<void> stop() async {
    _queue.clear();
    _currentItem = null;
    _isPlaying = false;
    await audioOutput.stop();
  }

  void dispose() {
    stop();
    audioOutput.dispose();
  }
}
