import 'package:flutter/material.dart';

/// Equatorial clinic atrium: dusk ink, copper filament, pulse teal, linen.
abstract final class HulkaLook {
  static const ink = Color(0xFF07141A);
  static const atrium = Color(0xFF0B2A2E);
  static const pulse = Color(0xFF1FA8A0);
  static const copper = Color(0xFFE2A45A);
  static const linen = Color(0xFFF4EFE4);
  static const paper = Color(0xFFFFFBF4);
  static const ember = Color(0xFFD94B32);

  static const easeOut = Cubic(0.23, 1.0, 0.32, 1.0);
  static const easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  static const press = Duration(milliseconds: 140);
  static const ui = Duration(milliseconds: 200);
  static const carousel = Duration(milliseconds: 720);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: pulse,
      brightness: Brightness.light,
      primary: const Color(0xFF0E6F6A),
      secondary: copper,
      surface: paper,
      error: ember,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: linen,
      fontFamily: 'Georgia',
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper.withValues(alpha: 0.88),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: copper.withValues(alpha: 0.35)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: pulse, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pulse,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: paper,
        selectedIconTheme: const IconThemeData(color: pulse),
        selectedLabelTextStyle: const TextStyle(color: atrium, fontWeight: FontWeight.w600),
        indicatorColor: pulse.withValues(alpha: 0.16),
      ),
    );
  }
}

bool hulkaReduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);
