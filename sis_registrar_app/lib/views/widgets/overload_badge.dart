import 'package:flutter/material.dart';

String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

/// Small "Overload" chip; the tooltip says who approved it and why.
class OverloadBadge extends StatelessWidget {
  final double termUnits;
  final double maxUnits;
  final String? approvedBy;
  final String? reason;

  const OverloadBadge({
    super.key,
    required this.termUnits,
    required this.maxUnits,
    this.approvedBy,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final approved = approvedBy != null;
    final color = approved ? const Color(0xFFB45309) : const Color(0xFFDC2626);
    return Tooltip(
      message: approved
          ? 'Approved by $approvedBy: ${reason ?? ''}'
          : 'Over the unit limit with no approval recorded.',
      child: Container(
        key: const ValueKey('overload_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: approved ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          'Overload ${_units(termUnits)}/${_units(maxUnits)}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

/// Full-width note for the student's Study Load window.
class OverloadBanner extends StatelessWidget {
  final double termUnits;
  final double maxUnits;
  final String? approvedBy;
  final String? reason;

  const OverloadBanner({
    super.key,
    required this.termUnits,
    required this.maxUnits,
    this.approvedBy,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final approved = approvedBy != null;
    final text = approved
        ? 'Overload: ${_units(termUnits)} of ${_units(maxUnits)} units. Approved by $approvedBy — "${reason ?? ''}"'
        : 'Overload: ${_units(termUnits)} of ${_units(maxUnits)} units. No approval is recorded.';
    return Container(
      key: const ValueKey('overload_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: approved ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18,
              color: approved ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: approved ? const Color(0xFF92400E) : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
