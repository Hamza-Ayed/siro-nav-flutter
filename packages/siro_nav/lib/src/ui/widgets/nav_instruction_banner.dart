import 'package:flutter/material.dart';
import 'package:siro_nav_core/siro_nav_core.dart';

/// Top banner displaying upcoming maneuver, turn distance, and street name.
class NavInstructionBanner extends StatelessWidget {
  final InstructionEvent? instruction;

  const NavInstructionBanner({super.key, required this.instruction});

  @override
  Widget build(BuildContext context) {
    if (instruction == null) return const SizedBox.shrink();

    final inst = instruction!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.95), // Slate-900
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(
          children: [
            // Maneuver Icon Box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7), // Sky blue
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getManeuverIcon(inst.maneuverType),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),

            // Instruction Details
            Expanded(
              child: Column(
                crossAxisAlignment:
                    isRtl ? CrossEntropyRtl.right : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDistance(inst.distanceMeters),
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inst.instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (inst.streetName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      inst.streetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getManeuverIcon(int sign) {
    switch (sign) {
      case -3:
        return Icons.turn_sharp_left;
      case -2:
        return Icons.turn_left;
      case -1:
        return Icons.turn_slight_left;
      case 1:
        return Icons.turn_slight_right;
      case 2:
        return Icons.turn_right;
      case 3:
        return Icons.turn_sharp_right;
      case 4:
      case 5:
        return Icons.place;
      case 6:
        return Icons.rotate_right; // Roundabout
      case 7:
        return Icons.fork_right;
      case -7:
        return Icons.fork_left;
      default:
        return Icons.straight;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return 'بعد ${(meters / 1000).toStringAsFixed(1)} كم';
    }
    return 'بعد ${meters.round()} م';
  }
}

class CrossEntropyRtl {
  static const CrossAxisAlignment right = CrossAxisAlignment.start;
}
