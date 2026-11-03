import 'dart:math' as math;
import '../models/nav_point.dart';

/// Result of projecting a raw GPS point onto a route polyline.
class SnappedResult {
  final NavPoint snappedPoint;
  final int segmentIndex;
  final double crossTrackDistanceMeters;
  final double distanceAlongRouteMeters;

  const SnappedResult({
    required this.snappedPoint,
    required this.segmentIndex,
    required this.crossTrackDistanceMeters,
    required this.distanceAlongRouteMeters,
  });
}

/// Snaps raw GPS coordinates onto the route polyline inside a forward-moving window.
class MapMatcher {
  static const int _windowLookahead = 30;
  static const int _windowLookbehind = 5;

  /// Segments this close to the best match count as a tie, and the earlier one wins.
  static const double _nearTieMeters = 15.0;

  /// Snaps [rawPoint] onto [polyline] within a search window around [lastKnownSegmentIndex].
  static SnappedResult snapToPolyline({
    required NavPoint rawPoint,
    required List<NavPoint> polyline,
    int lastKnownSegmentIndex = 0,
  }) {
    if (polyline.isEmpty) {
      return SnappedResult(
        snappedPoint: rawPoint,
        segmentIndex: 0,
        crossTrackDistanceMeters: 0.0,
        distanceAlongRouteMeters: 0.0,
      );
    }

    if (polyline.length == 1) {
      final dist = rawPoint.distanceTo(polyline.first);
      return SnappedResult(
        snappedPoint: polyline.first,
        segmentIndex: 0,
        crossTrackDistanceMeters: dist,
        distanceAlongRouteMeters: 0.0,
      );
    }

    // Determine sliding search window to keep CPU near zero on mobile devices
    final int totalSegments = polyline.length - 1;
    final int startIdx = math.max(0, lastKnownSegmentIndex - _windowLookbehind);
    final int endIdx =
        math.min(totalSegments, lastKnownSegmentIndex + _windowLookahead);

    double minDistance = double.infinity;
    for (int i = startIdx; i < endIdx; i++) {
      final projected =
          _projectPointOnSegment(rawPoint, polyline[i], polyline[i + 1]);
      final dist = rawPoint.distanceTo(projected);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    // Take the earliest segment that is nearly as close as the best one. A route
    // can pass the same place twice (a loop or a U-turn), and the earlier pass
    // is the one the vehicle is on. Only the window is searched, so progress
    // never jumps ahead.
    int bestSegmentIndex = lastKnownSegmentIndex.clamp(0, totalSegments - 1);
    double bestDistance = minDistance;
    NavPoint bestSnappedPoint = rawPoint;
    for (int i = startIdx; i < endIdx; i++) {
      final projected =
          _projectPointOnSegment(rawPoint, polyline[i], polyline[i + 1]);
      final dist = rawPoint.distanceTo(projected);
      if (dist <= minDistance + _nearTieMeters) {
        bestSegmentIndex = i;
        bestDistance = dist;
        bestSnappedPoint = projected;
        break;
      }
    }

    // Compute distance along route up to bestSnappedPoint
    double distanceAlongRoute = 0.0;
    for (int i = 0; i < bestSegmentIndex; i++) {
      distanceAlongRoute += polyline[i].distanceTo(polyline[i + 1]);
    }
    distanceAlongRoute +=
        polyline[bestSegmentIndex].distanceTo(bestSnappedPoint);

    return SnappedResult(
      snappedPoint: bestSnappedPoint,
      segmentIndex: bestSegmentIndex,
      crossTrackDistanceMeters: bestDistance,
      distanceAlongRouteMeters: distanceAlongRoute,
    );
  }

  /// Projects point P onto line segment AB using vector dot product.
  static NavPoint _projectPointOnSegment(NavPoint p, NavPoint a, NavPoint b) {
    final double dx = b.longitude - a.longitude;
    final double dy = b.latitude - a.latitude;

    if (dx == 0 && dy == 0) {
      return a;
    }

    // Project vector AP onto AB
    final double t =
        ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) /
            (dx * dx + dy * dy);

    // Clamp to segment boundaries
    final double clampedT = t.clamp(0.0, 1.0);

    final double projLng = a.longitude + clampedT * dx;
    final double projLat = a.latitude + clampedT * dy;

    // Preserve speed and bearing from raw point, or compute segment bearing
    final double segmentBearing = a.bearingTo(b);

    return NavPoint(
      latitude: projLat,
      longitude: projLng,
      heading: segmentBearing,
      speedKmh: p.speedKmh,
      altitude: a.altitude + clampedT * (b.altitude - a.altitude),
      accuracy: p.accuracy,
      timestamp: p.timestamp,
    );
  }
}
