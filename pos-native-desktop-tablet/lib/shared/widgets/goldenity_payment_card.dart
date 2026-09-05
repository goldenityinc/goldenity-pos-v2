import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

class GoldenityPaymentCard extends StatelessWidget {
  const GoldenityPaymentCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
    this.iconColor,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isSelected
        ? GoldenityColors.primary
        : GoldenityColors.border;
    final Color bgColor =
        isSelected ? GoldenityColors.primaryLight : const Color(0xFFFAFBFC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GoldenityRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GoldenityColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: GoldenityColors.border),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor ?? GoldenityColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: GoldenityTypography.fontFamilySans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GoldenityColors.text,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: GoldenityTypography.fontFamilySans,
                        fontSize: 12,
                        color: GoldenityColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? GoldenityColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? GoldenityColors.primary
                      : GoldenityColors.border2,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
