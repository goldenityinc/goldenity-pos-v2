import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/services/pin_service.dart';
import '../providers/auth_provider.dart';
import 'pin_pad.dart';

/// Gerbang PIN saat app dibuka ulang (sesi masih tersimpan). Cocokkan PIN →
/// lanjut ke shell (tanpa perlu server: mendukung mode offline). 5x salah →
/// paksa login ulang dengan password.
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String _value = '';
  String? _error;
  bool _shake = false;
  int _fails = 0;

  void _check() {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    final ok = ref.read(pinServiceProvider).verify(session.user.id, _value);
    if (ok) {
      ref.read(authNotifierProvider.notifier).markPinUnlocked();
      return;
    }
    _fails++;
    setState(() {
      _error = _fails >= 5
          ? 'Terlalu banyak percobaan. Login ulang.'
          : 'PIN salah (${5 - _fails} percobaan lagi).';
      _shake = true;
      _value = '';
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _shake = false);
    });
    if (_fails >= 5) {
      Future.delayed(const Duration(milliseconds: 700), () {
        ref.read(authNotifierProvider.notifier).logout(
              markExpired: true,
              message: 'PIN salah 5 kali. Silakan login ulang dengan password.',
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final name = session?.user.username ?? '';
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: GoldenityColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_outline, color: GoldenityColors.primary),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  const Text('Masukkan PIN',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                  const SizedBox(height: GoldenitySpacing.xs),
                  Text(name.isEmpty ? 'Buka aplikasi kasir' : 'Masuk sebagai $name',
                      style: const TextStyle(fontSize: 12.5, color: GoldenityColors.muted)),
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
                      if (_value.length >= 4 && _value.length <= 6) {
                        // auto-check di 6, atau tombol "Buka" utk 4-5.
                        if (_value.length == 6) _check();
                      }
                    },
                    onBackspace: () => setState(() {
                      if (_value.isNotEmpty) {
                        _value = _value.substring(0, _value.length - 1);
                      }
                    }),
                  ),
                  const SizedBox(height: GoldenitySpacing.sm),
                  if (_value.length >= 4 && _value.length < 6)
                    FilledButton(onPressed: _check, child: const Text('Buka'))
                  else
                    const SizedBox(height: 40),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextButton(
                    onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                    child: const Text('Login dengan password',
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
