import 'package:flutter/material.dart';

/// Pelvi brand + neutral color tokens (see docs/design-system.md).
class PelviColors {
  PelviColors._();

  // Brand — pink (primary) / purple (secondary)
  static const pink950 = Color(0xFF9D174D);
  static const pink700 = Color(0xFFDB2777);
  static const pink400 = Color(0xFFF472B6);
  static const pink200 = Color(0xFFFBCFE8);
  static const pink50 = Color(0xFFFCE7F3);

  static const purple950 = Color(0xFF4C1D95);
  static const purple700 = Color(0xFF7C3AED);
  static const purple400 = Color(0xFFA78BFA);
  static const purple50 = Color(0xFFF5F3FF);

  // Neutrals (Fudget-aligned)
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF5F5F7);
  static const ink = Color(0xFF1C1C1E);
  static const inkMuted = Color(0xFF8E8E93);
  static const inkInverse = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E5EA);
  static const chromeBorder = Color(0xFFD2D2D7);
  static const overlay = Color(0x732C1C1E); // ~45% ink

  // Semantic
  static const success = Color(0xFF007A33);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFB54708);
}
