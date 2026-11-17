import 'package:flutter/material.dart';
import '../../models/setup_models.dart';
import '../../theme/app_theme.dart';

/// Academic-term picker for page headers.
///
/// Works on term ids rather than model instances, so callers never have to keep
/// the selected object identical to the one in [terms].
class TermDropdown extends StatelessWidget {
  final List<AcademicTermModel> terms;

  /// The chosen term, or null for [allTermsLabel].
  final String? selectedTermId;
  final ValueChanged<String?> onChanged;

  /// Label for the "no filter" entry. Pass null to drop that entry entirely.
  final String? allTermsLabel;

  const TermDropdown({
    super.key,
    required this.terms,
    required this.selectedTermId,
    required this.onChanged,
    this.allTermsLabel = 'All terms',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const ValueKey('term_dropdown'),
          value: selectedTermId,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
            size: 20,
          ),
          // A dropdown's style replaces the theme's, so it must name the font itself.
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: [
            if (allTermsLabel != null)
              DropdownMenuItem<String?>(
                value: null,
                child: Text(allTermsLabel!),
              ),
            ...terms.map(
              (t) => DropdownMenuItem<String?>(
                value: t.termId,
                child: Text(t.isActive ? '${t.label} (Active)' : t.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
