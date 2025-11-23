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
          mainAxisSize: MainAxisSize.max,
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
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppFont.statValue,
                ),
              ),
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
