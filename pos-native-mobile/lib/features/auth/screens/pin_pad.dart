import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';

/// Dot-progress + numpad 3x4 dipakai bersama PinSetupScreen & PinUnlockScreen.
/// Selain tap, juga menerima keyboard fisik (tablet/desktop dengan keyboard) —
/// digit 0-9 (baris angka & numpad) + Backspace/Delete.
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

  static final Map<LogicalKeyboardKey, String> _digitKeys = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final digit = _digitKeys[event.logicalKey];
    if (digit != null) {
      if (value.length < maxLen) onKey(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      onBackspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
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
      ),
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
