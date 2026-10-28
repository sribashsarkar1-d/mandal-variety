import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/utils/platform_helper.dart';

class CommonBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  CommonBottomBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// A centralized bottom navigation setup translating to Material and Cupertino natively.
class CommonBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CommonBottomBarItem> items;

  static const double _barHeight = 64.0;
  static const double _iconSize = 24.0;
  static const double _minTouchTarget = 48.0;
  static const double _maxBarWidth = 560.0;
  static const double _horizontalPadding = 16.0;

  const CommonBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (PlatformHelper.isIOS) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        onTap: onTap,
        activeColor: theme.primaryColor,
        inactiveColor: theme.unselectedWidgetColor,
        backgroundColor: theme.colorScheme.surface,
        items: items.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: item.activeIcon != null ? Icon(item.activeIcon) : null,
            label: item.label,
          );
        }).toList(),
      );
    } else {
      // Material bottom bar: centered and anchored near the bottom edge.
      // SafeArea is used only to respect bottom insets; the bar background stays
      // visually attached to the bottom edge (not floating).
      return Material(
        color: theme.colorScheme.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: SizedBox(
              height: _barHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 360
                      ? 8.0
                      : _horizontalPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxBarWidth),
                    child: Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isSelected = index == currentIndex;

                        return Expanded(
                          child: _BottomBarItemWidget(
                            item: item,
                            isSelected: isSelected,
                            onTap: () => onTap(index),
                            theme: theme,
                            iconSize: _iconSize,
                            minTouchTarget: _minTouchTarget,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class _BottomBarItemWidget extends StatelessWidget {
  final CommonBottomBarItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final double iconSize;
  final double minTouchTarget;

  const _BottomBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.iconSize,
    required this.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = theme.unselectedWidgetColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final TextStyle? labelStyle = theme.textTheme.labelMedium?.copyWith(
          color: theme.primaryColor,
          fontWeight: FontWeight.w600,
        );

        final availableWidth = constraints.maxWidth;
        final bool isNarrow = availableWidth < 105;
        final bool showLabel = isSelected && availableWidth >= 80;

        final double horizontalPadding = isSelected
            ? (showLabel ? (isNarrow ? 8.0 : 12.0) : 8.0)
            : (isNarrow ? 6.0 : 10.0);
        final double verticalPadding = 8.0;
        final double effectiveIconSize = isNarrow ? (iconSize - 2.0) : iconSize;

        final double computedLabelMaxWidth =
            (availableWidth - (horizontalPadding * 2) - effectiveIconSize - 6.0).clamp(
              0.0,
              110.0,
            );

        final Widget labelWidget = showLabel
            ? Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: computedLabelMaxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: labelStyle?.copyWith(
                        fontSize: isNarrow ? 11.5 : 12.0,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        return Semantics(
          selected: isSelected,
          button: true,
          label: item.label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minTouchTarget,
                  minWidth: minTouchTarget,
                ),
                child: Center(
                  child: ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      decoration: ShapeDecoration(
                        color: isSelected
                            ? theme.primaryColor.withValues(alpha: 0.14)
                            : Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected && item.activeIcon != null
                                ? item.activeIcon
                                : item.icon,
                            color: isSelected
                                ? theme.primaryColor
                                : unselectedColor,
                            size: effectiveIconSize,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.centerLeft,
                            child: labelWidget,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
