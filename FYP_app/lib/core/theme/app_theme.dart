import 'package:flutter/material.dart';

/// Semantic colors supporting both Warm High-Contrast Daylight mode (default,
/// optimized for elderly & low-vision readability) and Soft Dark mode.
class AppPalette {
  const AppPalette({
    required this.isLight,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.primary,
    required this.secondary,
    required this.danger,
    required this.success,
    required this.warning,
    required this.text,
    required this.muted,
  });

  final bool isLight;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color primary;
  final Color secondary;
  final Color danger;
  final Color success;
  final Color warning;
  final Color text;
  final Color muted;

  static const light = AppPalette(
    isLight: true,
    background: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEEF3F7),
    outline: Color(0xFFCFD8E3),
    primary: Color(0xFF0B6E7F),
    secondary: Color(0xFFC67100),
    danger: Color(0xFFD93025),
    success: Color(0xFF1E8E3E),
    warning: Color(0xFFD97706),
    text: Color(0xFF14202E),
    muted: Color(0xFF526375),
  );

  static const dark = AppPalette(
    isLight: false,
    background: Color(0xFF0E1621),
    surface: Color(0xFF172231),
    surfaceHigh: Color(0xFF203044),
    outline: Color(0xFF31455E),
    primary: Color(0xFF38BDF8),
    secondary: Color(0xFFFBBF24),
    danger: Color(0xFFEF4444),
    success: Color(0xFF34D399),
    warning: Color(0xFFF59E0B),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;
}

/// Static accent tokens retained for custom painters (radar/gaze/gauge).
class AppColors {
  static const background = Color(0xFF0E1621);
  static const surface = Color(0xFF172231);
  static const surfaceHigh = Color(0xFF203044);
  static const outline = Color(0xFF31455E);

  static const primary = Color(0xFF0B6E7F);
  static const primaryBright = Color(0xFF38BDF8);
  static const secondary = Color(0xFFD97706);
  static const danger = Color(0xFFD93025);
  static const success = Color(0xFF1E8E3E);
  static const warning = Color(0xFFD97706);

  static const text = Color(0xFF14202E);
  static const muted = Color(0xFF526375);
}

ThemeData buildAppTheme({required bool light}) {
  final p = light ? AppPalette.light : AppPalette.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: light ? Brightness.light : Brightness.dark,
  ).copyWith(
    primary: p.primary,
    onPrimary: light ? Colors.white : const Color(0xFF06131F),
    secondary: p.secondary,
    error: p.danger,
    surface: p.surface,
    onSurface: p.text,
    outline: p.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: p.text, size: 24),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: light ? 0.5 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.outline, width: 1.1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: p.outline, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primary.withValues(alpha: 0.14),
      selectedIconTheme: IconThemeData(color: p.primary, size: 28),
      unselectedIconTheme: IconThemeData(color: p.muted, size: 26),
      selectedLabelTextStyle: TextStyle(
        color: p.primary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: p.muted,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primary.withValues(alpha: 0.15),
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? p.primary : p.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? p.primary : p.muted,
          size: 26,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.8),
      ),
      labelStyle: TextStyle(color: p.muted, fontSize: 14),
      hintStyle: TextStyle(color: p.muted, fontSize: 14),
    ),
    dividerTheme: DividerThemeData(color: p.outline, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: light ? const Color(0xFF1E293B) : p.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
    ),
  );
}
