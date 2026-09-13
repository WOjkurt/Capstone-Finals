import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';

Widget _buildPlaceholderBody({
  required IconData icon,
  required String title,
  required String description,
}) {
  return Expanded(
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Scaffold Ready — Feature View Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MyClassesPlaceholderView extends StatelessWidget {
  const MyClassesPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'My Classes',
          subtitle: 'View and manage your assigned subject offerings and student rosters.',
        ),
        _buildPlaceholderBody(
          icon: Icons.class_rounded,
          title: 'My Classes',
          description:
              'Assigned class lists, schedules, and student masterlists will be displayed here.',
        ),
      ],
    );
  }
}

class GradesPlaceholderView extends StatelessWidget {
  const GradesPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Grades',
          subtitle: 'Input, calculate, and submit student midterm and final grades.',
        ),
        _buildPlaceholderBody(
          icon: Icons.grade_rounded,
          title: 'Grade Submission',
          description:
              'Batch grade sheet entry, single student submission, and grade review tools will be displayed here.',
        ),
      ],
    );
  }
}

class GradeCorrectionsPlaceholderView extends StatelessWidget {
  const GradeCorrectionsPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Grade Corrections',
          subtitle: 'Submit requests to correct already-submitted grades.',
        ),
        _buildPlaceholderBody(
          icon: Icons.assignment_late_rounded,
          title: 'Grade Corrections',
          description:
              'Teacher correction requests, status tracking, and justification submissions will be displayed here.',
        ),
      ],
    );
  }
}

class ProgramOverviewPlaceholderView extends StatelessWidget {
  const ProgramOverviewPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Program Overview',
          subtitle: 'Departmental scoping, curriculum oversight, and class tracking.',
        ),
        _buildPlaceholderBody(
          icon: Icons.account_tree_rounded,
          title: 'Program Overview',
          description:
              'Program Head curriculum monitoring, faculty load overview, and department statistics will be displayed here.',
        ),
      ],
    );
  }
}
