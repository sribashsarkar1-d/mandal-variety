import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryItemWidget extends StatelessWidget {
  const CategoryItemWidget({
    super.key,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String? imageUrl;

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.16)
                    : theme.colorScheme.surfaceContainerHigh,
              ),
              child: ClipOval(
                child: _hasImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          icon,
                          color: isSelected
                              ? selectedColor
                              : theme.colorScheme.onSurfaceVariant,
                          size: 26,
                        ),
                      )
                    : Icon(
                        icon,
                        color: isSelected
                            ? selectedColor
                            : theme.colorScheme.onSurfaceVariant,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? selectedColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
