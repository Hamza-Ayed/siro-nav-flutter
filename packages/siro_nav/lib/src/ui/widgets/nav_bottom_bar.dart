import 'package:flutter/material.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Bottom trip bar showing remaining ETA, remaining distance, arrival time, and stop button.
class NavBottomBar extends StatelessWidget {
  final ProgressEvent? progress;
  final VoidCallback onStopNavigation;

  const NavBottomBar({
    super.key,
    required this.progress,
    required this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final int remainingSec = progress?.remainingDurationSeconds ?? 0;
    final double remainingM = progress?.remainingDistanceMeters ?? 0.0;

    final int minutes = (remainingSec / 60).round();
    final arrivalTime = DateTime.now().add(Duration(seconds: remainingSec));
    final String formattedTime =
        '${arrivalTime.hour % 12 == 0 ? 12 : arrivalTime.hour % 12}:${arrivalTime.minute.toString().padLeft(2, '0')} ${arrivalTime.hour >= 12 ? 'م' : 'ص'}';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.96), // Slate-900
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(
          children: [
            // Close / Cancel Button
            GestureDetector(
              onTap: onStopNavigation,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child:
                    const Icon(Icons.close, color: Color(0xFFEF4444), size: 24),
              ),
            ),
            const SizedBox(width: 16),

            // Time & ETA
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatEta(minutes),
                        style: const TextStyle(
                          color: Color(0xFF10B981), // Emerald green
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($formattedTime)',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDistance(remainingM),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEta(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMin = minutes % 60;
      return '$hours س $remMin د';
    }
    return '$minutes دقيقة';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} كم متبقية';
    }
    return '${meters.round()} م متبقية';
  }
}
