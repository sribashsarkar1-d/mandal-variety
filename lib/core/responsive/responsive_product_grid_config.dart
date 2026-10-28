import 'package:flutter/material.dart';

/// Centralized configuration and dimension calculations for responsive product grids and cards.
///
/// Ensures consistent 2-column layouts and 1:1 product image proportions
/// across mobile screen widths (320px to 440px+).
class ResponsiveProductGridConfig {
  static const double defaultHorizontalPadding = 32.0; // 16 left + 16 right
  static const double defaultCrossAxisSpacing = 12.0;
  static const double defaultMainAxisSpacing = 12.0;
  static const int defaultCrossAxisCount = 2;

  /// Calculates individual card width given the container width (screen width or constraint).
  static double calculateCardWidth({
    required double containerWidth,
    double horizontalPadding = defaultHorizontalPadding,
    double crossAxisSpacing = defaultCrossAxisSpacing,
    int crossAxisCount = defaultCrossAxisCount,
  }) {
    final available = containerWidth - horizontalPadding - (crossAxisSpacing * (crossAxisCount - 1));
    return (available / crossAxisCount).clamp(120.0, 400.0);
  }

  /// Calculates content height needed below the 1:1 product image.
  ///
  /// Accommodates:
  /// - Product name (up to 2 lines)
  /// - Price and discount
  /// - Category pill
  /// - Full-width Add to Cart button with proper touch target
  static double calculateContentHeight(double cardWidth) {
    if (cardWidth < 155.0) {
      return 138.0;
    } else if (cardWidth < 175.0) {
      return 148.0;
    } else {
      return 156.0;
    }
  }

  /// Calculates total card height (1:1 image + content section).
  static double calculateCardHeight(double cardWidth) {
    return cardWidth + calculateContentHeight(cardWidth);
  }

  /// Calculates child aspect ratio for grid delegates.
  static double calculateChildAspectRatio(double cardWidth) {
    final height = calculateCardHeight(cardWidth);
    return height > 0 ? (cardWidth / height) : 0.52;
  }

  /// Creates a responsive [SliverGridDelegateWithFixedCrossAxisCount] using exact [mainAxisExtent].
  static SliverGridDelegateWithFixedCrossAxisCount createGridDelegate({
    required double containerWidth,
    double horizontalPadding = defaultHorizontalPadding,
    double crossAxisSpacing = defaultCrossAxisSpacing,
    double mainAxisSpacing = defaultMainAxisSpacing,
    int crossAxisCount = defaultCrossAxisCount,
  }) {
    final cardWidth = calculateCardWidth(
      containerWidth: containerWidth,
      horizontalPadding: horizontalPadding,
      crossAxisSpacing: crossAxisSpacing,
      crossAxisCount: crossAxisCount,
    );
    final cardHeight = calculateCardHeight(cardWidth);

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      mainAxisExtent: cardHeight,
    );
  }
}
