import 'package:flutter/material.dart';

abstract class GoldenityElevation {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> btnPrimary = [
    BoxShadow(
      color: Color(0x4D1D4ED8),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> btnSuccess = [
    BoxShadow(
      color: Color(0x4D16A34A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x2E000000),
      blurRadius: 48,
      offset: Offset(0, 24),
    ),
  ];
}
