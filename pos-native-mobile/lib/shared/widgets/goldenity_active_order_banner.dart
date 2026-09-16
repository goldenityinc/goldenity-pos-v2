import 'package:flutter/material.dart';

import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

class GoldenityActiveOrderBanner extends StatelessWidget {
  const GoldenityActiveOrderBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.leadingIcon = Icons.restaurant,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(GoldenityRadius.sm),
              ),
              child: Icon(
                leadingIcon,
                size: 18,
                color: const Color(0xFF92400E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: GoldenityTypography.fontFamilySans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: GoldenityTypography.fontFamilySans,
                        fontSize: 12,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: Color(0xFF92400E),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
