import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class IntegerInputFieldFeed extends StatelessWidget {
  const IntegerInputFieldFeed({
    required this.controller,
    super.key,
    this.label, // ← no longer required
    this.maxValue,
  });
  final TextEditingController controller;
  final String? label; // ← now optional
  final int? maxValue;

  @override
  Widget build(BuildContext context) {
    // ── If no label, just return the field directly — no Column ──
    if (label == null) {
      return TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: AppTheme.fontSize13,
          color: AppTheme.grey800,
        ),
        decoration: InputDecoration(
          hintText: '0',
          isCollapsed: true, // ← removes ALL extra padding
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing8, // ← minimal vertical padding
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: AppTheme.white,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Required';
          final parsed = int.tryParse(value);
          if (parsed == null) return 'Invalid';
          if (parsed < 0) return 'Min 0';
          if (maxValue != null && parsed > maxValue!) return 'Max $maxValue';
          return null;
        },
      );
    }

    // ── With label ───────────────────────────────────────────────
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontSize: AppTheme.fontSize11,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey700,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: AppTheme.fontSize13,
            color: AppTheme.grey800,
          ),
          decoration: InputDecoration(
            hintText: '0',
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: const BorderSide(color: AppTheme.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: const BorderSide(color: AppTheme.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: const BorderSide(
                color: AppTheme.primaryRed,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: AppTheme.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Required';
            final parsed = int.tryParse(value);
            if (parsed == null) return 'Invalid';
            if (parsed < 0) return 'Min 0';
            if (maxValue != null && parsed > maxValue!) return 'Max $maxValue';
            return null;
          },
        ),
      ],
    );
  }
}







