import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';

/// Shared placeholder card — NOT wrapped in Expanded so it works
/// inside both Column-only and SingleChildScrollView contexts.
Widget _buildPlaceholderBody({
  required IconData icon,
  required String title,
  required String description,
}) {
  return Padding(
    // Adaptive padding: generous on wide screens, comfortable on narrow.
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    ),
  );
}

/// Wraps a view's PageHeader + placeholder body in a scrollable Column
/// so narrow widths (375 px, 414 px) never overflow.
Widget _buildScrollableView({
  required String pageTitle,
  required String pageSubtitle,
  required IconData icon,
  required String cardTitle,
  required String cardDescription,
}) {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: pageTitle, subtitle: pageSubtitle),
        _buildPlaceholderBody(
          icon: icon,
          title: cardTitle,
          description: cardDescription,
        ),
      ],
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────

class MySchedulePlaceholderView extends StatelessWidget {
  const MySchedulePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildScrollableView(
      pageTitle: 'My Schedule',
      pageSubtitle:
          'View your enrolled subjects, class sections, and weekly schedule.',
      icon: Icons.calendar_today_rounded,
      cardTitle: 'My Schedule',
      cardDescription:
          'Your enrolled classes, class schedules, rooms, and instructor details will be displayed here.',
    );
  }
}

class MyGradesPlaceholderView extends StatelessWidget {
  const MyGradesPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildScrollableView(
      pageTitle: 'My Grades',
      pageSubtitle: 'View your midterm and final grades per academic term.',
      icon: Icons.grade_rounded,
      cardTitle: 'My Grades',
      cardDescription:
          'Official subject grades, remarks, and GPA for cleared terms will be displayed here.',
    );
  }
}

class ClearanceStatusPlaceholderView extends StatelessWidget {
  const ClearanceStatusPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildScrollableView(
      pageTitle: 'Clearance Status',
      pageSubtitle:
          'Check your grade viewing clearance across academic terms.',
      icon: Icons.verified_user_rounded,
      cardTitle: 'Clearance Status',
      cardDescription:
          'Term clearance status, registrar clearance timestamps, and hold notices will be displayed here.',
    );
  }
}

class ProfilePlaceholderView extends StatelessWidget {
  const ProfilePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildScrollableView(
      pageTitle: 'Profile',
      pageSubtitle:
          'Your student account details, program, and academic standing.',
      icon: Icons.person_rounded,
      cardTitle: 'Student Profile',
      cardDescription:
          'Student LRN, degree program, year level, enrollment status, and personal details will be displayed here.',
    );
  }
}
