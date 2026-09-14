import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/theme/app_theme.dart';
import 'package:sis_teacher_app/views/main_layout_view.dart';

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

  test('MainLayoutView nav items for Teacher role (3) contains 3 items', () {
    final items = MainLayoutView.buildNavItems(role: 3, roleName: 'Teacher');
    expect(items.length, 3);
    expect(items.map((i) => i['title']).toList(), [
      'My Classes',
      'Grades',
      'Grade Corrections',
    ]);
  });

  test('MainLayoutView nav items for Program Head role (4) contains 5 items including Program Overview and Faculty', () {
    final items = MainLayoutView.buildNavItems(role: 4, roleName: 'Program Head');
    expect(items.length, 5);
    expect(items.map((i) => i['title']).toList(), [
      'My Classes',
      'Grades',
      'Grade Corrections',
      'Program Overview',
      'Faculty',
    ]);
  });
}
