import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';

/// Modal / dialog konsisten sesuai Figma arch-sleek.
///
/// Spesifikasi (getComputedStyle dari situs Figma yang dipublish):
/// - lebar 420, radius 16, padding 24, gap internal 18
/// - overlay `rgba(0,0,0,0.45)`, tanpa blur
/// - shadow `rgba(0,0,0,0.2) 0 20px 60px`
/// - judul 16/800, label field 13/600 `#374151`
/// - tombol h44 radius 10 — "Batal" outline `#E2E8F0` teks `#374151`,
///   primary bg `#1D4ED8` putih (bisa override warna)
Future<T?> showGoldenityDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  String primaryLabel = 'Simpan',
  String? secondaryLabel = 'Batal',
  Color? primaryColor,
  IconData? primaryIcon,
  double width = 420,
  bool barrierDismissible = true,
  // Return `true`/nilai apa pun untuk menutup; return `null` untuk tetap
  // terbuka (mis. validasi gagal). Boleh async.
  required Future<T?> Function() onPrimary,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: const Color(0x73000000), // rgba(0,0,0,0.45)
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, a1, a2, _) {
      final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: _GoldenityDialogShell<T>(
            title: title,
            subtitle: subtitle,
            primaryLabel: primaryLabel,
            secondaryLabel: secondaryLabel,
            primaryColor: primaryColor,
            primaryIcon: primaryIcon,
            width: width,
            onPrimary: onPrimary,
            child: child,
          ),
        ),
      );
    },
  );
}

class _GoldenityDialogShell<T> extends StatefulWidget {
  const _GoldenityDialogShell({
    required this.title,
    this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryColor,
    required this.primaryIcon,
    required this.width,
    required this.onPrimary,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color? primaryColor;
  final IconData? primaryIcon;
  final double width;
  final Future<T?> Function() onPrimary;

  @override
  State<_GoldenityDialogShell<T>> createState() => _GoldenityDialogShellState<T>();
}

class _GoldenityDialogShellState<T> extends State<_GoldenityDialogShell<T>> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.onPrimary();
      if (result != null && mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? GoldenityColors.primary;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widget.width,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 60, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(widget.subtitle!,
                              style: const TextStyle(fontSize: 12, color: GoldenityColors.muted)),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close_rounded, size: 18, color: GoldenityColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(child: SingleChildScrollView(child: widget.child)),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (widget.secondaryLabel != null) ...[
                    Expanded(
                      child: _DialogButton(
                        label: widget.secondaryLabel!,
                        onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _DialogButton(
                      label: widget.primaryLabel,
                      icon: widget.primaryIcon,
                      onTap: _run,
                      filled: true,
                      color: primary,
                      busy: _busy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.filled,
    this.color,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = color ?? GoldenityColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? c : GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            border: filled ? null : Border.all(color: GoldenityColors.border),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: filled ? Colors.white : GoldenityColors.text2),
                      const SizedBox(width: 6),
                    ],
                    Text(label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: filled ? Colors.white : const Color(0xFF374151),
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Field berlabel untuk isi modal (label 13/600 `#374151` + TextField rapi).
class GoldenityModalField extends StatelessWidget {
  const GoldenityModalField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: GoldenityColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: GoldenityColors.disabled),
            filled: true,
            fillColor: GoldenityColors.surface2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              borderSide: const BorderSide(color: GoldenityColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              borderSide: const BorderSide(color: GoldenityColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drawer detail sisi-kanan (Figma: lebar 320, shadow `-4px 0 20px rgba(15,23,42,.08)`,
/// header id biru + tanggal + close, body scroll, footer aksi sticky).
Future<T?> showGoldenityDetailDrawer<T>({
  required BuildContext context,
  required String id,
  String? subtitle,
  required Widget child,
  List<Widget> actions = const [],
  double width = 320,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: id,
    barrierColor: const Color(0x40000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, a1, a2, _) {
      final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
      return Align(
        alignment: Alignment.centerRight,
        child: FractionalTranslation(
          translation: Offset(1 - curved.value, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: GoldenityColors.surface,
                boxShadow: [
                  BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(-4, 0)),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(id,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: GoldenityColors.primary)),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(subtitle,
                                      style: const TextStyle(
                                          fontSize: 12, color: GoldenityColors.muted)),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).maybePop(),
                            child: const Icon(Icons.close_rounded, size: 18, color: GoldenityColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: GoldenityColors.border),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: child,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const Divider(height: 1, color: GoldenityColors.border),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: actions[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Tombol aksi untuk footer drawer (outline / warna teks kustom).
class GoldenityDrawerAction extends StatelessWidget {
  const GoldenityDrawerAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.borderColor,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? GoldenityColors.text2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor ?? GoldenityColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
