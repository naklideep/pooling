import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riyal1/core/theme/app_colors.dart';
import 'package:riyal1/core/theme/app_theme.dart';

void main() {
  group('AppColors & AppTheme Tests', () {
    test('AppColors palette verifies primary brand values', () {
      expect(AppColors.navy, const Color(0xFF1A2340));
      expect(AppColors.yellow, const Color(0xFFFFCC00));
      expect(AppColors.background, const Color(0xFFF3F5F9));
      expect(AppColors.textSecondary, const Color(0xFF7B8497));
    });

    test('AppTheme creates valid ThemeData with Material 3 enabled', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppColors.navy);
      expect(theme.colorScheme.secondary, AppColors.yellow);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('AppTheme card shadow and shape helpers are non-null', () {
      expect(AppTheme.cardShadow, isNotEmpty);
      expect(AppTheme.subtleShadow, isNotEmpty);
      expect(AppTheme.radiusSm, const BorderRadius.all(Radius.circular(10)));
      expect(AppTheme.radiusMd, const BorderRadius.all(Radius.circular(16)));
      expect(AppTheme.radiusLg, const BorderRadius.all(Radius.circular(22)));
    });
  });
}
