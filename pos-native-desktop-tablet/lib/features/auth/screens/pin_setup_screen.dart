import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/services/pin_service.dart';
import '../providers/auth_provider.dart';
import 'pin_pad.dart';

/// Ditawarkan sekali setelah login pertama + pilih cabang. Bikin PIN 4–6 digit
/// supaya nanti bisa buka mode offline tanpa server. Bisa dilewati.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  int _step = 1; // 1 = buat, 2 = ulangi
  String _first = '';
  String _value = '';
  String? _error;
  bool _shake = false;

  Future<void> _onComplete() async {
    if (_step == 1) {
      setState(() {
        _first = _value;
        _value = '';
        _step = 2;
        _error = null;
      });
      return;
    }
    if (_value != _first) {
      setState(() {
        _error = 'PIN tidak sama, ulangi.';
        _shake = true;
        _value = '';
      });
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _shake = false);
      });
      return;
    }
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    await ref.read(pinServiceProvider).setPin(session.user.id, _value);
    ref.read(authNotifierProvider.notifier).markPinUnlocked();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN offline dibuat.')),
      );
    }
  }

  void _skip() {
    final session = ref.read(currentSessionProvider);
    if (session != null) {
      ref.read(pinServiceProvider).markSkipped(session.user.id);
    }
    ref.read(authNotifierProvider.notifier).markPinUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(GoldenitySpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_step/2',
                      style: const TextStyle(
                          color: GoldenityColors.muted,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'JetBrainsMono')),
                  const SizedBox(height: GoldenitySpacing.sm),
                  Text(_step == 1 ? 'Buat PIN Offline' : 'Ulangi PIN',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                  const SizedBox(height: GoldenitySpacing.xs),
                  const Text(
                    'Dipakai untuk masuk cepat / mode offline saat internet bermasalah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: GoldenityColors.muted),
                  ),
                  const SizedBox(height: GoldenitySpacing.xl),
                  PinPad(
                    value: _value,
                    maxLen: 6,
                    error: _error,
                    shake: _shake,
                    onKey: (k) {
                      setState(() {
                        _value += k;
                        _error = null;
                      });
                      if (_value.length == 6) _onComplete();
                    },
                    onBackspace: () => setState(() {
                      if (_value.isNotEmpty) {
                        _value = _value.substring(0, _value.length - 1);
                      }
                    }),
                  ),
                  const SizedBox(height: GoldenitySpacing.sm),
                  if (_value.length >= 4 && _value.length < 6)
                    TextButton(onPressed: _onComplete, child: const Text('Lanjut'))
                  else
                    const SizedBox(height: 36),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Lewati, atur nanti',
                        style: TextStyle(color: GoldenityColors.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
