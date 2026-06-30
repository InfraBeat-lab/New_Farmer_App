import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

enum BadgeType { success, info, warning, error, custom }

class CustomBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const CustomBadge({
    super.key,
    required this.text,
    this.type = BadgeType.success,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  Color get _backgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    switch (type) {
      case BadgeType.success:
        return AppTheme.successLight;
      case BadgeType.info:
        return AppTheme.infoLight;
      case BadgeType.warning:
        return AppTheme.warningLight;
      case BadgeType.error:
        return AppTheme.errorLight;
      case BadgeType.custom:
        return AppTheme.badgeYellow;
    }
  }

  Color get _textColor {
    if (textColor != null) return textColor!;
    switch (type) {
      case BadgeType.success:
        return AppTheme.successDark;
      case BadgeType.info:
        return AppTheme.infoDark;
      case BadgeType.warning:
        return AppTheme.warningDark;
      case BadgeType.error:
        return AppTheme.error;
      case BadgeType.custom:
        return AppTheme.badgeYellowText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppTheme.fontSize12, color: _textColor),
            const SizedBox(width: AppTheme.spacing4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.fontSize11,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}







