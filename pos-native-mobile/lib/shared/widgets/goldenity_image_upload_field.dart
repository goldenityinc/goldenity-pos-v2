import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';
import '../../core/services/image_upload_service.dart';

/// Field upload gambar (Issue #3) — menggantikan input URL manual.
///
/// Menampilkan preview gambar sekarang (dari [value] URL), tombol "Pilih Gambar"
/// (buka dialog file Windows → upload ke backend → callback [onChanged] dengan
/// URL hasil upload), dan tombol hapus.
class GoldenityImageUploadField extends StatefulWidget {
  const GoldenityImageUploadField({
    super.key,
    required this.label,
    required this.value,
    required this.authToken,
    required this.onChanged,
    this.kind = 'other',
    this.helperText,
    this.previewHeight = 96,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String authToken;
  final ValueChanged<String?> onChanged;
  final String kind;
  final String? helperText;
  final double previewHeight;
  final bool enabled;

  @override
  State<GoldenityImageUploadField> createState() =>
      _GoldenityImageUploadFieldState();
}

class _GoldenityImageUploadFieldState extends State<GoldenityImageUploadField> {
  final ImageUploadService _service = ImageUploadService();
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await _service.pickAndUpload(
        authToken: widget.authToken,
        kind: widget.kind,
      );
      if (!mounted) return;
      if (url != null) widget.onChanged(url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasImage = (widget.value ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: textTheme.labelMedium?.copyWith(
            color: GoldenityColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: GoldenitySpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: widget.previewHeight,
              height: widget.previewHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: GoldenityColors.surface2,
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
                border: Border.all(color: GoldenityColors.border),
              ),
              child: hasImage
                  ? Image.network(
                      widget.value!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: GoldenityColors.disabled,
                      ),
                      loadingBuilder: (ctx, child, prog) => prog == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                    )
                  : const Icon(Icons.image_outlined,
                      color: GoldenityColors.disabled, size: 28),
            ),
            const SizedBox(width: GoldenitySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: GoldenitySpacing.sm,
                    runSpacing: GoldenitySpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            widget.enabled && !_busy ? _pick : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(hasImage ? 'Ganti Gambar' : 'Pilih Gambar'),
                      ),
                      if (hasImage && widget.enabled && !_busy)
                        TextButton.icon(
                          onPressed: () => widget.onChanged(null),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: GoldenityColors.error),
                          label: const Text('Hapus',
                              style: TextStyle(color: GoldenityColors.error)),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: GoldenitySpacing.xs),
                    Text(
                      _error!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.error),
                    ),
                  ] else if (widget.helperText != null) ...[
                    const SizedBox(height: GoldenitySpacing.xs),
                    Text(
                      widget.helperText!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
