import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class IntegerInputFieldVacc extends StatelessWidget {
  /// The controller bound to a State-level variable (never create inline).
  final TextEditingController controller;

  /// Must match the height of the adjacent Instock read-only box (default 38).
  final double height;

  /// Optional upper-bound — shows "Max X" error if exceeded.
  final int? maxValue;

  const IntegerInputFieldVacc({
    super.key,
    required this.controller,
    this.height = 38,
    this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        // Blocks everything except digits — no minus, no decimal, no letters
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.grey800),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: const TextStyle(color: AppTheme.grey400),
          isCollapsed: true, // removes Flutter's default extra height
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing10,
          ),
          // Normal border
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          // Idle border
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.grey300),
          ),
          // Focused border — red highlight
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
          ),
          // Validation error border
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        // ── Validation rules ──────────────────────────────────────────
        validator: (value) {
          // Empty check
          if (value == null || value.trim().isEmpty) return 'Required';
          // Integer check
          final parsed = int.tryParse(value);
          if (parsed == null) return 'Invalid';
          // Non-negative check
          if (parsed < 0) return 'Min 0';
          // Stock limit check (optional)
          if (maxValue != null && parsed > maxValue!) return 'Max $maxValue';
          return null; // ✅ all good
        },
      ),
    );
  }
}







