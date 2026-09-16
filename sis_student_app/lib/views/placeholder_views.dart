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

class MySchedulePlaceholderView extends StatelessWidget {
  const MySchedulePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'My Schedule',
          subtitle: 'View your enrolled subjects, class sections, and weekly schedule.',
        ),
        _buildPlaceholderBody(
          icon: Icons.calendar_today_rounded,
          title: 'My Schedule',
          description:
              'Your enrolled classes, class schedules, rooms, and instructor details will be displayed here.',
        ),
      ],
    );
  }
}

class MyGradesPlaceholderView extends StatelessWidget {
  const MyGradesPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'My Grades',
          subtitle: 'View your midterm and final grades per academic term.',
        ),
        _buildPlaceholderBody(
          icon: Icons.grade_rounded,
          title: 'My Grades',
          description:
              'Official subject grades, remarks, and GPA for cleared terms will be displayed here.',
        ),
      ],
    );
  }
}

class ClearanceStatusPlaceholderView extends StatelessWidget {
  const ClearanceStatusPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Clearance Status',
          subtitle: 'Check your grade viewing clearance across academic terms.',
        ),
        _buildPlaceholderBody(
          icon: Icons.verified_user_rounded,
          title: 'Clearance Status',
          description:
              'Term clearance status, registrar clearance timestamps, and hold notices will be displayed here.',
        ),
      ],
    );
  }
}

class ProfilePlaceholderView extends StatelessWidget {
  const ProfilePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Profile',
          subtitle: 'Your student account details, program, and academic standing.',
        ),
        _buildPlaceholderBody(
          icon: Icons.person_rounded,
          title: 'Student Profile',
          description:
              'Student LRN, degree program, year level, enrollment status, and personal details will be displayed here.',
        ),
      ],
    );
  }
}

