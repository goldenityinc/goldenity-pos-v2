import 'package:flutter/material.dart';

import 'goldenity_colors.dart';
import 'goldenity_typography.dart';

ThemeData buildGoldenityTheme() {
  const ColorScheme colorScheme = ColorScheme.light(
    primary: GoldenityColors.primary,
    onPrimary: GoldenityColors.primaryFg,
    primaryContainer: GoldenityColors.primaryLight,
    secondary: GoldenityColors.primary,
    secondaryContainer: GoldenityColors.primaryLight,
    surface: GoldenityColors.surface,
    onSurface: GoldenityColors.text,
    error: GoldenityColors.error,
    onError: Colors.white,
  );

  final TextTheme textTheme = buildGoldenityTextTheme(GoldenityColors.text);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: GoldenityColors.bg,
    textTheme: textTheme,
    fontFamily: GoldenityTypography.fontFamilySans,
    dividerColor: GoldenityColors.border,
    cardColor: GoldenityColors.surface,
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: GoldenityColors.border),
      ),
      color: GoldenityColors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: GoldenityColors.surface,
      foregroundColor: GoldenityColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.headlineSmall,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GoldenityColors.primary,
        foregroundColor: GoldenityColors.primaryFg,
        disabledBackgroundColor: GoldenityColors.disabled,
        disabledForegroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: textTheme.labelLarge,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        side: const BorderSide(color: GoldenityColors.border2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: GoldenityColors.surface2,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: GoldenityColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: GoldenityColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: GoldenityColors.primary, width: 2),
      ),
      hintStyle: TextStyle(
        fontFamily: GoldenityTypography.fontFamilySans,
        color: GoldenityColors.muted,
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        fontFamily: GoldenityTypography.fontFamilySans,
        color: GoldenityColors.text2,
        fontSize: 14,
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      GoldenityBizColors.fnb,
    ],
  );
}
