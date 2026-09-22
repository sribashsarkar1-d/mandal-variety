import 'package:flutter/material.dart';

enum AppCardVariant { info, action, selectable }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final bool isSelected; // Only applies to AppCardVariant.selectable
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor,
  }) : variant = AppCardVariant.info,
       onTap = null,
       isSelected = false;

  /// A card that reacts to being pressed (ink ripple vs nothing).
  const AppCard.action({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor,
  }) : variant = AppCardVariant.action,
       isSelected = false;

  /// A card that acts as a selectable item (e.g., in a grid or list of options).
  const AppCard.selectable({
    super.key,
    required this.child,
    required this.onTap,
    required this.isSelected,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor,
  }) : variant = AppCardVariant.selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color defaultColor = backgroundColor ?? theme.colorScheme.surface.withValues(alpha: 0.85);
    Border? border;

    if (variant == AppCardVariant.selectable) {
      if (isSelected) {
        defaultColor = theme.primaryColor.withValues(alpha: 0.1);
        border = Border.all(color: theme.primaryColor, width: 2);
      } else {
        border = Border.all(color: theme.dividerColor, width: 1);
      }
    }

    Widget content = Container(padding: padding, child: child);

    if (variant == AppCardVariant.action ||
        variant == AppCardVariant.selectable) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: defaultColor,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: variant == AppCardVariant.selectable && !isSelected
            ? [] // No shadow on unselected selectable cards to flatten design
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: content,
    );
  }
}
