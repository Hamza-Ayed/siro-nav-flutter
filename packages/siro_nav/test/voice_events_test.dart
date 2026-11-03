import 'package:flutter_test/flutter_test.dart';
import 'package:siro_nav/siro_nav.dart';

const _assetFolder = 'packages/siro_nav/assets/audio/ar/';

void main() {
  late LoggingAudioOutput output;
  late NavVoiceEngine engine;

  setUp(() {
    output = LoggingAudioOutput();
    final catalog = NavVoiceCatalog.fromMap({
      'arrived_successfully': const NavVoicePrompt(
        id: 'arrived_successfully',
        file: 'arrived_successfully.mp3',
        text: 'وصلت',
        category: 'arrival',
        priority: 0,
      ),
      'camera_ahead': const NavVoicePrompt(
        id: 'camera_ahead',
        file: 'camera_ahead.mp3',
        text: 'كاميرا',
        category: 'safety',
        priority: 1,
      ),
    });
    engine = NavVoiceEngine(catalog: catalog, audioOutput: output);
  });

  tearDown(() => engine.dispose());

  test('arrival plays the arrival clip', () async {
    await engine.handleNavEvent(ArrivalEvent(
      finalPosition: NavPoint.fromLatLng(31.9, 35.9),
      totalDistanceTraveledMeters: 1000,
      totalDurationSeconds: 60,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(output.lastPlayedAsset, '${_assetFolder}arrived_successfully.mp3');
  });

  test('a camera with an unknown limit plays the camera-ahead clip', () async {
    await engine.handleNavEvent(SpeedCameraEvent(
      camera: const SpeedCamera(
        id: 'cam_1',
        latitude: 31.9,
        longitude: 35.9,
        speedLimitKmh: 0,
        type: 'fixed',
        alertDistanceMeters: 300,
      ),
      distanceMeters: 250,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(output.lastPlayedAsset, '${_assetFolder}camera_ahead.mp3');
  });
}
