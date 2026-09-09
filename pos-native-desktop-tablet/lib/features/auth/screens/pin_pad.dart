import 'package:flutter/material.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';

/// Dot-progress + numpad 3x4 dipakai bersama PinSetupScreen & PinUnlockScreen.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.maxLen,
    required this.onKey,
    required this.onBackspace,
    this.error,
    this.shake = false,
  });

  final String value;
  final int maxLen;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final String? error;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(shake ? 8 : 0, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(maxLen, (i) {
              final filled = i < value.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? GoldenityColors.primary : Colors.transparent,
                  border: Border.all(
                    color: error != null
                        ? GoldenityColors.error
                        : filled
                            ? GoldenityColors.primary
                            : GoldenityColors.border2,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 22,
          child: error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: GoldenitySpacing.sm),
                  child: Text(error!,
                      style: const TextStyle(
                          color: GoldenityColors.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                )
              : null,
        ),
        const SizedBox(height: GoldenitySpacing.md),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _Key(
                      label: k,
                      onTap: k.isEmpty
                          ? null
                          : k == '<'
                              ? onBackspace
                              : () {
                                  if (value.length < maxLen) onKey(k);
                                },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(width: 66, height: 66);
    return Material(
      color: GoldenityColors.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 66,
          height: 66,
          child: Center(
            child: label == '<'
                ? const Icon(Icons.backspace_outlined, size: 22, color: GoldenityColors.text2)
                : Text(label,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrainsMono',
                        color: GoldenityColors.text)),
          ),
        ),
      ),
    );
  }
}
