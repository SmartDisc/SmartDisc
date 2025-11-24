import 'package:flutter/material.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sublabel;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sublabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardGradientStart,
              AppColors.cardGradientEnd,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha((0.12 * 255).round()),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(label, style: AppFont.statLabel),
            const SizedBox(height: 4),
            // Make the value scale down if there's not enough space instead of overflowing
              // Render value with nicer typography: show primary line large, optional second line smaller
              const SizedBox(height: 6),
              ConstrainedBox(
                // allow slightly larger box to avoid small overflows on larger fonts
                constraints: const BoxConstraints(maxHeight: 88),
                child: Builder(builder: (ctx) {
                  final lines = value.split('\n');
                  final primary = lines.isNotEmpty ? lines[0] : '';
                  final rest = lines.length > 1 ? lines.sublist(1).join(' ') : '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary value (prominent)
                      Text(primary, style: AppFont.statValueLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                      if (rest.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(rest, style: AppFont.subheadline, overflow: TextOverflow.ellipsis, maxLines: 2),
                      ],
                    ],
                  );
                }),
              ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sublabel, style: AppFont.subheadline),
            ],
          ],
        ),
      ),
    );
  }
}
