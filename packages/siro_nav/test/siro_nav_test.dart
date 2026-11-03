import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siro_nav/siro_nav.dart';

void main() {
  group('SiroNav Flutter SDK - Controller Unit Tests', () {
    test('Initializes reactive notifiers in default state', () {
      final config = NavConfig(
        apiKey: 'siro_live_test_key_123',
        driverId: 'captain_77',
      );
      final controller = SiroNavController(config: config);

      expect(controller.isNavigating.value, isFalse);
      expect(controller.currentInstruction.value, isNull);
      expect(controller.currentProgress.value, isNull);
      expect(controller.currentSpeedKmh.value, equals(0.0));
      expect(controller.upcomingCamera.value, isNull);
      expect(controller.activeError.value, isNull);

      controller.dispose();
    });
  });

  group('SiroNav Voice Engine - Offline Guidance Tests', () {
    late NavVoiceCatalog catalog;
    late LoggingAudioOutput audioOutput;
    late NavVoiceEngine voiceEngine;

    setUp(() {
      final dummyManifest = {
        'prompts': {
          'turn_right_now': {
            'file': 'turn_right_now.mp3',
            'text': 'انْعَطِفْ يَمِينًا الآن',
            'category': 'maneuver_immediate',
            'priority': 0,
          },
          'after_100m_turn_right': {
            'file': 'after_100m_turn_right.mp3',
            'text': 'بَعْدَ مِئَةِ مِتْرٍ، انْعَطِفْ يَمِينًا',
            'category': 'maneuver_prepare',
            'priority': 2,
          },
          'camera_ahead': {
            'file': 'camera_ahead.mp3',
            'text': 'انْتَبِهْ، كَامِيرَا مُرَاقَبَةِ سُرْعَةٍ أَمَامَك',
            'category': 'safety',
            'priority': 1,
          },
          'speed_warning': {
            'file': 'speed_warning.mp3',
            'text':
                'يُرْجَى تَخْفِيفُ السُّرْعَة، لَقَدْ تَجَاوَزْتَ السُّرْعَةَ الْمُحَدَّدَة',
            'category': 'safety',
            'priority': 1,
          },
          'rerouting': {
            'file': 'rerouting.mp3',
            'text': 'جَارٍ إِعَادَةُ احْتِسَابِ الْمَسَار',
            'category': 'route_status',
            'priority': 3,
          },
          'arrived_successfully': {
            'file': 'arrived_successfully.mp3',
            'text': 'لَقَدْ وَصَلْتَ إِلَى وُجْهَتِكَ بِنَجَاح',
            'category': 'arrival',
            'priority': 0,
          },
        }
      };

      final map = <String, NavVoicePrompt>{};
      (dummyManifest['prompts'] as Map).forEach((k, v) {
        map[k as String] =
            NavVoicePrompt.fromJson(k, v as Map<String, dynamic>);
      });

      catalog = NavVoiceCatalog.fromMap(map);
      audioOutput = LoggingAudioOutput();
      voiceEngine = NavVoiceEngine(
        catalog: catalog,
        audioOutput: audioOutput,
      );
    });

    test('Prompt resolution matches quantization ladder accurately', () {
      // Immediate turn right
      expect(
        voiceEngine.resolvePromptId(
          maneuverType: 2,
          distanceMeters: 20.0,
          priority: 0,
        ),
        equals('turn_right_now'),
      );

      // 100m advance turn right
      expect(
        voiceEngine.resolvePromptId(
          maneuverType: 2,
          distanceMeters: 100.0,
          priority: 2,
        ),
        equals('after_100m_turn_right'),
      );

      // 500m advance turn left
      expect(
        voiceEngine.resolvePromptId(
          maneuverType: -2,
          distanceMeters: 500.0,
          priority: 2,
        ),
        equals('after_500m_turn_left'),
      );
    });

    test('Controller routes engine events directly to voice engine', () async {
      final config = NavConfig(apiKey: 'siro_live_test_key_123');
      final controller = SiroNavController(
        config: config,
        voiceEngine: voiceEngine,
      );

      expect(controller.voiceEngine, isNotNull);
      expect(voiceEngine.isMuted, isFalse);

      voiceEngine.toggleMute();
      expect(voiceEngine.isMuted, isTrue);

      controller.dispose();
    });
  });

  group('SiroNav Flutter SDK - UI Widgets Tests', () {
    testWidgets(
        'NavInstructionBanner renders instruction and formatted distance in Arabic',
        (tester) async {
      final event = InstructionEvent(
        stepIndex: 1,
        instruction: 'انعطف يميناً إلى شارع المدينة المنورة',
        streetName: 'شارع المدينة المنورة',
        maneuverType: 2,
        distanceMeters: 250,
        timeSeconds: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: NavInstructionBanner(instruction: event),
            ),
          ),
        ),
      );

      expect(
          find.text('انعطف يميناً إلى شارع المدينة المنورة'), findsOneWidget);
      expect(find.text('شارع المدينة المنورة'), findsOneWidget);
      expect(find.text('بعد 250 م'), findsOneWidget);
    });

    testWidgets(
        'NavBottomBar renders remaining ETA and triggers cancel callback',
        (tester) async {
      final progress = ProgressEvent(
        rawPosition: NavPoint.fromLatLng(31.95, 35.90),
        snappedPosition: NavPoint.fromLatLng(31.95, 35.90),
        distanceToNextManeuverMeters: 200,
        remainingDistanceMeters: 4500,
        remainingDurationSeconds: 600, // 10 minutes
        currentSpeedKmh: 45,
        currentStepIndex: 1,
        progressFraction: 0.5,
      );

      bool stopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: NavBottomBar(
                progress: progress,
                onStopNavigation: () {
                  stopped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('10 دقيقة'), findsOneWidget);
      expect(find.text('4.5 كم متبقية'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      expect(stopped, isTrue);
    });

    testWidgets('NavSpeedBadge displays speed and radar alert pill',
        (tester) async {
      final camera = SpeedCamera(
        id: 'cam_1',
        latitude: 31.95,
        longitude: 35.90,
        speedLimitKmh: 60,
        alertDistanceMeters: 300,
      );

      final camEvent = SpeedCameraEvent(
        camera: camera,
        distanceMeters: 180,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: NavSpeedBadge(
                currentSpeedKmh: 75.0,
                upcomingCamera: camEvent,
                isOverspeeding: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('75'), findsOneWidget);
      expect(find.text('كم/س'), findsOneWidget);
      expect(find.text('كاميرا 60 كم/س (180م)'), findsOneWidget);
    });
  });
}
