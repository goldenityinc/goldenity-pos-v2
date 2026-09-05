import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

class GoldenityCounterButton extends StatefulWidget {
  const GoldenityCounterButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.buttonSize = 32.0,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double buttonSize;

  @override
  State<GoldenityCounterButton> createState() => _GoldenityCounterButtonState();
}

class _GoldenityCounterButtonState extends State<GoldenityCounterButton> {
  Color _minusColor = GoldenityColors.text2;
  Color _plusColor = GoldenityColors.primary;

  bool get _canMinus => widget.value > widget.min;
  bool get _canPlus => widget.value < widget.max;

  void _handleMinus() {
    if (!_canMinus) return;
    widget.onChanged(widget.value - 1);
  }

  void _handlePlus() {
    if (!_canPlus) return;
    widget.onChanged(widget.value + 1);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.buttonSize;
    return Container(
      height: s,
      decoration: BoxDecoration(
        color: GoldenityColors.surface2,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MouseRegion(
            onEnter: (_) => setState(() {
              _minusColor = _canMinus
                  ? GoldenityColors.error
                  : GoldenityColors.disabled;
            }),
            onExit: (_) => setState(() {
              _minusColor =
                  _canMinus ? GoldenityColors.text2 : GoldenityColors.disabled;
            }),
            child: GestureDetector(
              onTap: _canMinus ? _handleMinus : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: s,
                height: s,
                child: Icon(
                  Icons.remove,
                  size: s * 0.5,
                  color: _canMinus ? _minusColor : GoldenityColors.disabled,
                ),
              ),
            ),
          ),
          Container(
            width: s * 1.2,
            alignment: Alignment.center,
            child: Text(
              widget.value.toString(),
              style: const TextStyle(
                fontFamily: GoldenityTypography.fontFamilyMono,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GoldenityColors.text,
              ),
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() {
              _plusColor = _canPlus
                  ? GoldenityColors.primaryHover
                  : GoldenityColors.disabled;
            }),
            onExit: (_) => setState(() {
              _plusColor =
                  _canPlus ? GoldenityColors.primary : GoldenityColors.disabled;
            }),
            child: GestureDetector(
              onTap: _canPlus ? _handlePlus : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: s,
                height: s,
                child: Icon(
                  Icons.add,
                  size: s * 0.5,
                  color: _canPlus ? _plusColor : GoldenityColors.disabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
