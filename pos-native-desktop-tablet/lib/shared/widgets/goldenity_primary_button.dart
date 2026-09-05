import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

enum GoldenityButtonState { normal, hovered, pressed, disabled }

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

  Color get _bgColor {
    final Color base = widget.backgroundColor ?? GoldenityColors.primary;
    switch (_state) {
      case GoldenityButtonState.hovered:
        return widget.backgroundColor ?? GoldenityColors.primaryHover;
      case GoldenityButtonState.pressed:
        return base.withValues(alpha: 0.85);
      case GoldenityButtonState.disabled:
      case GoldenityButtonState.normal:
        return _isDisabled ? GoldenityColors.disabled : base;
    }
  }

  Color get _fgColor {
    return widget.foregroundColor ??
        (_isDisabled ? Colors.white60 : GoldenityColors.primaryFg);
  }

  List<BoxShadow> get _effectiveShadow {
    if (_isDisabled) return const [];
    return widget.shadow ?? GoldenityElevation.btnPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
        onTap: _isDisabled
            ? null
            : () {
                Future<void>.delayed(const Duration(milliseconds: 100), () {
                  widget.onPressed?.call();
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(GoldenityRadius.xl),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
