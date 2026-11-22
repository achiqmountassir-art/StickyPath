import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color pink = Color(0xFFFF2D87);
  static const Color pinkDeep = Color(0xFFE81A74);
  static const Color ink = Color(0xFF07070A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color softWhite = Color(0xFFE6E6EA);
  static const Color mutedWhite = Color(0xFFB4B4BC);
}

abstract final class AppFonts {
  static const String brush = 'PermanentMarker';
  static const String sans = 'Inter';

  static TextStyle sansStyle({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.white,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
