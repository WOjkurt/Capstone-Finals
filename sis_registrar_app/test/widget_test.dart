import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/theme/app_theme.dart';

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
}

