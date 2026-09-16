import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_student_app/theme/app_theme.dart';
import 'package:sis_student_app/views/main_layout_view.dart';

void main() {
  test('AppColors matches Don Bosco Technical College - Cebu official seal', () {
    // Primary gear blue
    expect(AppColors.primary, const Color(0xFF016BC1));
    expect(AppColors.primaryDark, const Color(0xFF014F8E));

    // Accent colors from seal
    expect(AppColors.accentGreen, const Color(0xFF16A34A));
    expect(AppColors.accentAmber, const Color(0xFFFF9601));
    expect(AppColors.accentGold, const Color(0xFFFACC15));

    // Deep navy undertone for sidebar
    expect(AppColors.sidebarBg, const Color(0xFF0A192F));
  });

  test('AppTheme generates valid lightTheme with DBTC primary seed', () {
    final theme = AppTheme.lightTheme;
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.scaffoldBg);
  });

  test('MainLayoutView nav items for Student role (5) contains 4 items', () {
    final items = MainLayoutView.buildNavItems(role: 5, roleName: 'Student');
    expect(items.length, 4);
    expect(items.map((i) => i['title']).toList(), [
      'My Schedule',
      'My Grades',
      'Clearance Status',
      'Profile',
    ]);
  });
}
