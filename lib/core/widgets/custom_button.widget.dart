import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

enum ButtonType { primary, secondary, tertiary }

class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.text,
    super.key,
    this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.isExpanded = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    final Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppTheme.spacing8),
          ],
          Text(text),
        ],
      ],
    );

    final decoration = _getDecoration();
    final textStyle = _getTextStyle(context);

    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacing12,
              horizontal: AppTheme.spacing20,
            ),
            child: DefaultTextStyle(style: textStyle, child: buttonChild),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration() {
    switch (type) {
      case ButtonType.primary:
        return const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.all(Radius.circular(AppTheme.radius12)),
        );
      case ButtonType.secondary:
        return BoxDecoration(
          color: AppTheme.grey200,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        );
      case ButtonType.tertiary:
        return BoxDecoration(
          color: AppTheme.primaryRed,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        );
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: AppTheme.fontSize15,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: AppTheme.fontSize15,
          fontWeight: FontWeight.w600,
        );

    switch (type) {
      case ButtonType.primary:
      case ButtonType.tertiary:
        return baseStyle.copyWith(color: AppTheme.white);
      case ButtonType.secondary:
        return baseStyle.copyWith(color: AppTheme.grey700);
    }
  }
}

class ButtonGroup extends StatelessWidget {
  const ButtonGroup({required this.buttons, super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.grey200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: buttons
              .map(
                (button) => Expanded(
                  child: SizedBox(width: double.infinity, child: button),
                ),
              )
              .toList()
              .fold<List<Widget>>([], (list, widget) {
                if (list.isNotEmpty) {
                  list.add(const SizedBox(width: AppTheme.spacing12));
                }
                list.add(widget);
                return list;
              }),
        ),
      ),
    );
  }
}







