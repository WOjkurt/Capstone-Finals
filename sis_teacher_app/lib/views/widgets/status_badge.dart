import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.pending({String label = 'Pending'}) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFFEF3C7),
      textColor: const Color(0xFF92400E),
      icon: Icons.access_time_rounded,
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}
