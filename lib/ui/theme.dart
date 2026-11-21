import 'package:flutter/material.dart';

const eShokPurple = Color(0xFF6C4AB6);
const eShokPurpleLight = Color(0xFFCBB9E8);
const eShokInk = Color(0xFF282234);
const eShokCanvas = Color(0xFFF8F7FB);
const eShokBorder = Color(0xFFE9E3F1);

ThemeData buildEShokFixTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: eShokPurple,
    brightness: Brightness.light,
    surface: Colors.white,
    primary: eShokPurple,
    secondary: eShokPurpleLight,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: eShokCanvas,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: eShokInk,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.white,
      titleTextStyle: TextStyle(color: eShokInk, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: eShokBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFBFAFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: eShokBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: eShokBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: eShokPurple, width: 1.6)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: eShokPurpleLight.withValues(alpha: .42),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        color: states.contains(WidgetState.selected) ? eShokPurple : const Color(0xFF847B91),
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        fontSize: 11,
      )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: eShokPurple,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: eShokPurple,
        side: const BorderSide(color: eShokPurpleLight),
        minimumSize: const Size(44, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    dividerColor: eShokBorder,
  );
}
