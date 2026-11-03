import 'package:siro_nav_core/siro_nav_core.dart';
import 'package:test/test.dart';

void main() {
  test('decodes the reference polyline from the Google encoding spec', () {
    final points = PolylineCodec.decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-5));
    expect(points[0].longitude, closeTo(-120.2, 1e-5));
    expect(points[1].latitude, closeTo(40.7, 1e-5));
    expect(points[1].longitude, closeTo(-120.95, 1e-5));
    expect(points[2].latitude, closeTo(43.252, 1e-5));
    expect(points[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('empty input decodes to no points', () {
    expect(PolylineCodec.decode(''), isEmpty);
  });

  test('a truncated string is rejected instead of returning bad points', () {
    // Ends in the middle of a value: the high bit is still set on the last char.
    expect(() => PolylineCodec.decode('_p~iF~ps|U_'), throwsFormatException);
  });
}
