import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? badge;
  final bool fullWidth;
  final Gradient? gradient;

  const InfoCard({
    super.key,
    required this.label,
    required this.value,
    this.badge,
    this.fullWidth = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.peachGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: AppTheme.fontSize11,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: AppTheme.fontSize14,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey800,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            badge!,
          ],
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? valueWidget;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.grey600),
          ),
          valueWidget ??
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey800,
                ),
              ),
        ],
      ),
    );
  }
}







