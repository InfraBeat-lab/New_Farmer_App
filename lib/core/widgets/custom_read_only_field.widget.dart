import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class CustomReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const CustomReadOnlyField({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontSize12,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey700,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.grey100,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(color: AppTheme.grey300),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: AppTheme.fontSize13,
              color: AppTheme.grey800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
