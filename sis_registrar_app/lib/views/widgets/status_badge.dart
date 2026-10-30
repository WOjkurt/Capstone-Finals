import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.onTap,
  });

  factory StatusBadge.noLrn({String label = 'No LRN', VoidCallback? onTap}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFEF3C7),
      textColor: const Color(0xFF92400E),
      icon: Icons.warning_amber_rounded,
      onTap: onTap,
    );
  }

  factory StatusBadge.pending({String label = 'Pending', VoidCallback? onTap}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFEF3C7),
      textColor: const Color(0xFF92400E),
      icon: Icons.access_time_rounded,
      onTap: onTap,
    );
  }

  factory StatusBadge.success({required String label}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFD1FAE5),
      textColor: const Color(0xFF065F46),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  factory StatusBadge.danger({required String label}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFEE2E2),
      textColor: const Color(0xFF991B1B),
      icon: Icons.cancel_outlined,
    );
  }

  factory StatusBadge.info({required String label}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFDBEAFE),
      textColor: const Color(0xFF1E40AF),
      icon: Icons.info_outline_rounded,
    );
  }

  factory StatusBadge.neutral({required String label}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFF3F4F6),
      textColor: const Color(0xFF4B5563),
    );
  }

  static Widget forLoadStatus(String status) {
    final s = status.trim();
    final lower = s.toLowerCase();
    if (lower == 'enrolled' || lower == 'active' || lower == 'completed') {
      return StatusBadge.success(label: s.isNotEmpty ? s : 'Enrolled');
    } else if (lower.contains('pending')) {
      return StatusBadge.pending(label: s.isNotEmpty ? s : 'Pending');
    } else if (lower == 'dropped' || lower == 'failed') {
      return StatusBadge.danger(label: s.isNotEmpty ? s : 'Dropped');
    } else if (lower == 'withdrawn') {
      return StatusBadge.neutral(label: s.isNotEmpty ? s : 'Withdrawn');
    } else if (lower == 'rejected') {
      return StatusBadge.neutral(label: 'Rejected');
    }
    return StatusBadge.neutral(label: s.isNotEmpty ? s : 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: badge,
        ),
      );
    }

    return badge;
  }
}
