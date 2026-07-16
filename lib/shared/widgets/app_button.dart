import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

enum AppButtonVariant { primary, info, warning, error, secondary }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
  });

  (Color, Color) _colors(ColorScheme colorScheme) {
    return switch (variant) {
      AppButtonVariant.primary => (colorScheme.primary, colorScheme.onPrimary),
      AppButtonVariant.info => (colorScheme.secondary, colorScheme.onSecondary),
      AppButtonVariant.warning => (AppColors.warning, Colors.black),
      AppButtonVariant.error => (colorScheme.error, colorScheme.onError),
      AppButtonVariant.secondary => (
        colorScheme.surfaceContainerHigh,
        colorScheme.onSurface,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor) = _colors(
      Theme.of(context).colorScheme,
    );

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
