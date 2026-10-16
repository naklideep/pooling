import 'package:flutter/material.dart';

/// Pooling brand color palette.
///
/// Use these tokens throughout the app instead of raw hex literals.
/// This makes theme changes and dark-mode support straightforward.
class AppColors {
  AppColors._();

  // ── Primary ───────────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF1A2340);
  static const Color navyDeep = Color(0xFF0D1726);
  static const Color navyMid = Color(0xFF1A2F5E);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color yellowDark = Color(0xFFD97706);
  static const Color yellowDim = Color(0x33FFCC00);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF3F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFEEF0F5);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A2340);
  static const Color textSecondary = Color(0xFF7B8497);
  static const Color textHint = Color(0xFFB0B8D0);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Borders / Shadows ─────────────────────────────────────────────────────
  static const Color border = Color(0xFFDDE0EE);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMed = Color(0x14000000);
}
