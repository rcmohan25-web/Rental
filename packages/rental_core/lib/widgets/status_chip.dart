import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

enum StatusTone { success, warning, danger, info, neutral }

/// Status chip. Always colour + icon + text (never colour alone).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, this.tone = StatusTone.neutral, super.key});

  final String label;
  final StatusTone tone;

  Color get _color => switch (tone) {
        StatusTone.success => BrandColors.success,
        StatusTone.warning => BrandColors.warning,
        StatusTone.danger => BrandColors.danger,
        StatusTone.info => BrandColors.info,
        StatusTone.neutral => BrandColors.textMuted,
      };

  IconData get _icon => switch (tone) {
        StatusTone.success => Icons.check_circle_outline,
        StatusTone.warning => Icons.schedule,
        StatusTone.danger => Icons.error_outline,
        StatusTone.info => Icons.info_outline,
        StatusTone.neutral => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
