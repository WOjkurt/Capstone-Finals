import 'package:flutter/material.dart';
import '../../models/setup_models.dart';
import '../../theme/app_theme.dart';

/// Compact academic-term picker used in page headers (grades, schedule).
class TermDropdown extends StatelessWidget {
  final List<AcademicTermModel> terms;

  /// Must be the same object instance as an element of [terms]
  /// (callers resolve it via terms.firstWhere, as the blocs do),
  /// or the DropdownButton cannot match its value.
  final AcademicTermModel? selected;
  final AcademicTermModel? activeTerm;
  final ValueChanged<AcademicTermModel> onChanged;

  const TermDropdown({
    super.key,
    required this.terms,
    required this.selected,
    required this.activeTerm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      // Caps the width on wide screens but still shrinks to whatever room the
      // row leaves it on a phone.
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AcademicTermModel>(
          value: selected,
          isDense: true,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          // A dropdown's style replaces the theme's, so it must name the font itself.
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          onChanged: (AcademicTermModel? newTerm) {
            if (newTerm != null) {
              onChanged(newTerm);
            }
          },
          items: terms.map((term) {
            final isCurrentActive =
                activeTerm?.termId == term.termId || term.isActive;
            return DropdownMenuItem<AcademicTermModel>(
              value: term,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(term.label, overflow: TextOverflow.ellipsis)),
                  if (isCurrentActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
