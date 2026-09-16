import 'package:flutter/material.dart';

abstract class GoldenityColors {
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primaryHover = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color primaryFg = Color(0xFFFFFFFF);

  static const Color sidebar = Color(0xFF0F172A);
  static const Color sidebarText = Color(0xFF94A3B8);
  /// Background item nav aktif di sidebar (rgba(29,78,216,0.15)).
  static const Color sidebarActive = Color(0x261D4ED8);

  static const Color bg = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF8FAFC);

  static const Color text = Color(0xFF0F172A);
  static const Color text2 = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color disabled = Color(0xFF94A3B8);
  /// Nomor baris, teks dekoratif (#CBD5E1).
  static const Color textXMuted = Color(0xFFCBD5E1);

  static const Color border = Color(0xFFE2E8F0);
  static const Color border2 = Color(0xFFCBD5E1);

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
}

@immutable
class GoldenityBizColors extends ThemeExtension<GoldenityBizColors> {
  const GoldenityBizColors({
    required this.base,
    required this.light,
    required this.dark,
    required this.textOnBase,
  });

  final Color base;
  final Color light;
  final Color dark;
  final Color textOnBase;

  static const GoldenityBizColors fnb = GoldenityBizColors(
    base: Color(0xFF1D4ED8),
    light: Color(0xFFEFF6FF),
    dark: Color(0xFF1E3A8A),
    textOnBase: Colors.white,
  );

  static const GoldenityBizColors retail = GoldenityBizColors(
    base: Color(0xFF7C3AED),
    light: Color(0xFFF5F3FF),
    dark: Color(0xFF5B21B6),
    textOnBase: Colors.white,
  );

  static const GoldenityBizColors service = GoldenityBizColors(
    base: Color(0xFF16A34A),
    light: Color(0xFFDCFCE7),
    dark: Color(0xFF15803D),
    textOnBase: Colors.white,
  );

  @override
  GoldenityBizColors copyWith({
    Color? base,
    Color? light,
    Color? dark,
    Color? textOnBase,
  }) {
    return GoldenityBizColors(
      base: base ?? this.base,
      light: light ?? this.light,
      dark: dark ?? this.dark,
      textOnBase: textOnBase ?? this.textOnBase,
    );
  }

  @override
  GoldenityBizColors lerp(GoldenityBizColors? other, double t) {
    if (other is! GoldenityBizColors) return this;
    return GoldenityBizColors(
      base: Color.lerp(base, other.base, t)!,
      light: Color.lerp(light, other.light, t)!,
      dark: Color.lerp(dark, other.dark, t)!,
      textOnBase: Color.lerp(textOnBase, other.textOnBase, t)!,
    );
  }
}
