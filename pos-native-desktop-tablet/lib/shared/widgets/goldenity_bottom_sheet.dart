import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';

class GoldenityBottomSheet extends StatelessWidget {
  const GoldenityBottomSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.92,
    this.backgroundColor,
    this.showHandle = true,
  });

  final Widget child;
  final double maxHeightFactor;
  final Color? backgroundColor;
  final bool showHandle;

  static const Duration slideUpDuration = Duration(milliseconds: 320);
  static const Curve slideUpCurve = Curves.easeOutQuart;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double maxHeightFactor = 0.92,
    bool showHandle = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: slideUpDuration,
      ),
      builder: (_) => GoldenityBottomSheet(
        backgroundColor: backgroundColor,
        maxHeightFactor: maxHeightFactor,
        showHandle: showHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FractionallySizedBox content = FractionallySizedBox(
      heightFactor: maxHeightFactor,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? GoldenityColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2E000000),
              blurRadius: 48,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showHandle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GoldenityColors.border2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
    return SafeArea(top: false, child: content);
  }
}
