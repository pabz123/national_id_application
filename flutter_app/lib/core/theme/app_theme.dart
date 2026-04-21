// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─── Brand colours ────────────────────────────────────────────────────────
const kBrandGreen = Color(0xFF0C3D28);
const kAccentGreen = Color(0xFF1A6B44);
const kLightGreen = Color(0xFFF0FAF4);
const kBorderGreen = Color(0xFFDEE8E2);
const kMintText = Color(0xFF7BBD9E);
const kPaleText = Color(0xFFC8E8D5);

/// ─── App-wide ThemeData ───────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrandGreen,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF4F8F5),
    textTheme: GoogleFonts.dmSansTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrandGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAFCFB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderGreen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccentGreen,
        side: const BorderSide(color: kBorderGreen),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderGreen),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kLightGreen,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
              color: kAccentGreen, fontSize: 12, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: Colors.black54, fontSize: 12);
      }),
    ),
  );
}
