import 'package:flutter/material.dart';

abstract class GoldenityTypography {
  static const String fontFamilySans = 'Inter';
  static const String fontFamilyMono = 'JetBrainsMono';
}

class GoldenityNumericTextStyle {
  static const TextStyle numericLarge = TextStyle(
    fontFamily: GoldenityTypography.fontFamilyMono,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericMedium = TextStyle(
    fontFamily: GoldenityTypography.fontFamilyMono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericSmall = TextStyle(
    fontFamily: GoldenityTypography.fontFamilyMono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle monoData = TextStyle(
    fontFamily: GoldenityTypography.fontFamilyMono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

extension GoldenityTextTheme on TextTheme {
  TextStyle get numericLarge => GoldenityNumericTextStyle.numericLarge;
  TextStyle get numericMedium => GoldenityNumericTextStyle.numericMedium;
  TextStyle get numericSmall => GoldenityNumericTextStyle.numericSmall;
  TextStyle get monoData => GoldenityNumericTextStyle.monoData;
}

TextTheme buildGoldenityTextTheme(Color textColor) {
  const String sans = GoldenityTypography.fontFamilySans;

  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: sans,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -1.0,
      color: textColor,
    ),
    headlineMedium: TextStyle(
      fontFamily: sans,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.5,
      color: textColor,
    ),
    headlineSmall: TextStyle(
      fontFamily: sans,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
      color: textColor,
    ),
    titleLarge: TextStyle(
      fontFamily: sans,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
      color: textColor,
    ),
    titleMedium: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: textColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: sans,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: textColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: sans,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: textColor,
    ),
    bodySmall: TextStyle(
      fontFamily: sans,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: textColor,
    ),
    labelLarge: TextStyle(
      fontFamily: sans,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -0.2,
      color: textColor,
    ),
    labelSmall: TextStyle(
      fontFamily: sans,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: 0.8,
      color: textColor,
    ),
  );
}
