import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

enum GoldenityButtonState { normal, hovered, pressed, disabled }

/// Tombol aksi utama — Design System handoff §05.
/// Default: gradient 135° `#1D4ED8 → #2563EB`, radius 10, shadow btnPrimary.
/// Pressed: gradient flat `#1E40AF → #1D4ED8`, shadow hilang.
/// Disabled: bg `#E2E8F0`, teks `#94A3B8`, tanpa shadow.
///
/// Jika [backgroundColor] diisi (mis. hijau success), pakai warna solid itu
/// (bukan gradient primary).
class GoldenityPrimaryButton extends StatefulWidget {
  const GoldenityPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.shadow,
    this.height = 44.0,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<BoxShadow>? shadow;
  final double height;
  final double? width;

  @override
  State<GoldenityPrimaryButton> createState() => _GoldenityPrimaryButtonState();
}

class _GoldenityPrimaryButtonState extends State<GoldenityPrimaryButton> {
  GoldenityButtonState _state = GoldenityButtonState.normal;

  bool get _isDisabled =>
      widget.onPressed == null ||
      widget.isLoading ||
      _state == GoldenityButtonState.disabled;

  bool get _pressed => _state == GoldenityButtonState.pressed;

  Gradient? get _gradient {
    if (_isDisabled || widget.backgroundColor != null) return null;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _pressed
          ? const <Color>[Color(0xFF1E40AF), Color(0xFF1D4ED8)]
          : const <Color>[Color(0xFF1D4ED8), Color(0xFF2563EB)],
    );
  }

  Color? get _solidColor {
    if (_isDisabled) return const Color(0xFFE2E8F0);
    final Color? bg = widget.backgroundColor;
    if (bg == null) return null; // pakai gradient
    return _pressed ? bg.withValues(alpha: 0.88) : bg;
  }

  Color get _fgColor {
    if (_isDisabled) return const Color(0xFF94A3B8);
    return widget.foregroundColor ?? Colors.white;
  }

  List<BoxShadow> get _effectiveShadow {
    if (_isDisabled || _pressed) return const <BoxShadow>[];
    if (widget.shadow != null) return widget.shadow!;
    return widget.backgroundColor == GoldenityColors.success
        ? GoldenityElevation.btnSuccess
        : GoldenityElevation.btnPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() {
        if (!_isDisabled) _state = GoldenityButtonState.hovered;
      }),
      onExit: (_) => setState(() {
        if (!_isDisabled) _state = GoldenityButtonState.normal;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() {
          if (!_isDisabled) _state = GoldenityButtonState.pressed;
        }),
        onTapUp: (_) => setState(() {
          if (!_isDisabled) _state = GoldenityButtonState.hovered;
        }),
        onTapCancel: () => setState(() {
          if (!_isDisabled) _state = GoldenityButtonState.normal;
        }),
        onTap: _isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _solidColor,
            gradient: _gradient,
            borderRadius: GoldenityRadius.buttonRadius,
            boxShadow: _effectiveShadow,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_fgColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (widget.icon != null) ...<Widget>[
                      Icon(widget.icon, size: 18, color: _fgColor),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: GoldenityTypography.fontFamilySans,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: _fgColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
