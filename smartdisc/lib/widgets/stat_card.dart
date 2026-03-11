import 'package:flutter/material.dart';
import '../styles/app_colors.dart';
import '../styles/app_font.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sublabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppFont.statLabel),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: Builder(builder: (ctx) {
                final lines = value.split('\n');
                final primary = lines.isNotEmpty ? lines[0] : '';
                final rest = lines.length > 1 ? lines.sublist(1).join(' ') : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      primary,
                      style: AppFont.statValue,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        rest,
                        style: AppFont.caption.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ],
                );
              }),
            ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sublabel, style: AppFont.caption),
            ],
          ],
        ),
      ),
    );
  }
}
