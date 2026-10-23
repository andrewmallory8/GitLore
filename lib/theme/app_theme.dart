import 'package:flutter/material.dart';

ThemeData gitLoreTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: brightness,
    primary: dark ? const Color(0xFF93B4FF) : const Color(0xFF2457D6),
    surface: dark ? const Color(0xFF161E2E) : Colors.white,
    onSurface: dark ? const Color(0xFFE8EDF7) : const Color(0xFF172033),
    surfaceContainerLow: dark
        ? const Color(0xFF111A2A)
        : const Color(0xFFF0F4FA),
    primaryContainer: dark ? const Color(0xFF263F70) : const Color(0xFFE6EEFF),
    onPrimaryContainer: dark
        ? const Color(0xFFE6EEFF)
        : const Color(0xFF173A83),
    onSurfaceVariant: dark ? const Color(0xFFA5B2C9) : const Color(0xFF53627B),
    outlineVariant: dark ? const Color(0xFF303D54) : const Color(0xFFDCE3EE),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0D1422)
        : const Color(0xFFF4F7FC),
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
  );
}
