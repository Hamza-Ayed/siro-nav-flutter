import 'package:siro_nav_core/siro_nav_core.dart';
import 'package:test/test.dart';

void main() {
  // A long route, 100 segments of about 55 m heading north. Longer than the
  // matcher's search window, so the far end is out of reach from the start.
  final polyline = [
    for (var i = 0; i <= 100; i++) NavPoint.fromLatLng(31.9 + i * 0.0005, 35.9),
  ];

  test('a fix near the route end is not snapped to the end from the start', () {
    final last = polyline.last;
    // About 110 m east of the end of the route.
    final farFix = NavPoint.fromLatLng(last.latitude, 35.9 + 0.001);

    final result = MapMatcher.snapToPolyline(
      rawPoint: farFix,
      polyline: polyline,
      lastKnownSegmentIndex: 0,
    );

    expect(result.segmentIndex, lessThanOrEqualTo(30));
    // Far from the matched part of the route, so the engine treats it as off-route.
    expect(result.crossTrackDistanceMeters, greaterThan(80));
  });

  test('a fix on the route snaps to its segment and stays on track', () {
    final onRoute = NavPoint.fromLatLng(31.9 + 10 * 0.0005, 35.9);

    final result = MapMatcher.snapToPolyline(
      rawPoint: onRoute,
      polyline: polyline,
      lastKnownSegmentIndex: 8,
    );

    expect(result.segmentIndex, inInclusiveRange(9, 10));
    expect(result.crossTrackDistanceMeters, lessThan(1));
  });

  test('on a route that passes the same place twice, the earlier pass wins',
      () {
    // Leg 1 goes north from (31.9, 35.9). Leg 2 comes back south about 9 m east
    // of it, so the second pass is the nearer one for a fix 25 m east of the start.
    final loop = [
      for (var i = 0; i <= 10; i++)
        NavPoint.fromLatLng(31.9 + i * 0.0002, 35.9),
      for (var j = 0; j <= 10; j++)
        NavPoint.fromLatLng(31.902 - j * 0.0002, 35.90010),
    ];
    final fix = NavPoint.fromLatLng(31.9001, 35.90028);

    final result = MapMatcher.snapToPolyline(
      rawPoint: fix,
      polyline: loop,
      lastKnownSegmentIndex: 0,
    );

    expect(result.segmentIndex, lessThan(10),
        reason: 'must not pick the return leg');
  });
}
