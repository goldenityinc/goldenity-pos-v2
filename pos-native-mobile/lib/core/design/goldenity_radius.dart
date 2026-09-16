import 'package:flutter/widgets.dart';

/// Skala radius — Design System handoff §04.
///  xs 4  · sm 6  · md 8  · lg 10 · xl 12 · xl2 14 · xl3 20 · full ∞
abstract class GoldenityRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 10.0;
  static const double xl = 12.0;
  static const double xxl = 14.0;
  static const double xxxl = 20.0;
  static const double xl2 = 14.0; // alias handoff
  static const double xl3 = 20.0; // alias handoff
  static const double full = 9999.0;

  /// Kartu dashboard / panel inventaris → 14px.
  static BorderRadius get cardRadius => BorderRadius.circular(xl2);

  /// Tombol primary/secondary + input field → 10px.
  static BorderRadius get buttonRadius => BorderRadius.circular(lg);
  static BorderRadius get inputRadius => BorderRadius.circular(lg);

  /// Modal / payment sheet / drawer → 20px.
  static BorderRadius get modalRadius => BorderRadius.circular(xl3);

  static BorderRadius get chipRadius => BorderRadius.circular(full);
}
