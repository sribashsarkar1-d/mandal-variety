import 'package:flutter/material.dart';

import '../../../core/responsive/responsive_product_grid_config.dart';
import '../../../core/theme/app_colors.dart';

/// Static minimum display: 1.8 s (controlled in [ProductListingView]).
class ProductListingSkeletonSliver extends StatefulWidget {
  const ProductListingSkeletonSliver({super.key});

  @override
  State<ProductListingSkeletonSliver> createState() =>
      _ProductListingSkeletonSliverState();
}

class _ProductListingSkeletonSliverState
    extends State<ProductListingSkeletonSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card background — matches real ProductGridCard surface
    final cardBg =
        isDark ? AppColors.carbonBlack : AppColors.lightSurface;

    // Bone resting colour — slightly different from card bg
    final boneBase = isDark
        ? AppColors.skeletonWithShimmerEffectDarkGrey
        : AppColors.skeletonWithShimmerEffectLightGrey;

    // Shimmer highlight colour
    final boneHighlight = isDark
        ? AppColors.skeletonWithShimmerEffectDarkWhite
        : AppColors.skeletonWithShimmerEffectWhite;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        // pos: -0.5 → 1.5  — the highlight band travels left-to-right
        final pos = -0.5 + _shimmer.value * 2.0;

        Shader buildShader(Rect bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            boneBase,
            boneBase,
            boneHighlight,
            boneBase,
            boneBase,
          ],
          stops: [
            0.0,
            (pos - 0.3).clamp(0.0, 1.0),
            pos.clamp(0.0, 1.0),
            (pos + 0.3).clamp(0.0, 1.0),
            1.0,
          ],
        ).createShader(bounds);

        return SliverPadding(
          // Same padding as ProductGridSliver default
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final gridDelegate = ResponsiveProductGridConfig.createGridDelegate(
                containerWidth: constraints.crossAxisExtent,
                horizontalPadding: 0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                crossAxisCount: 2,
              );

              return SliverGrid(
                gridDelegate: gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (_, _) => _SkeletonCard(
                    cardBg: cardBg,
                    boneBase: boneBase,
                    buildShader: buildShader,
                  ),
                  childCount: 8,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Color cardBg;
  final Color boneBase;
  final Shader Function(Rect) buildShader;

  const _SkeletonCard({
    required this.cardBg,
    required this.boneBase,
    required this.buildShader,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: buildShader,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                color: boneBase,
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand / category chip
                    FractionallySizedBox(
                      widthFactor: 0.45,
                      child: _Bone(height: 9, boneBase: boneBase),
                    ),
                    const SizedBox(height: 6),

                    // Product name — line 1
                    FractionallySizedBox(
                      widthFactor: 0.92,
                      child: _Bone(height: 12, boneBase: boneBase),
                    ),
                    const SizedBox(height: 4),

                    // Product name — line 2
                    FractionallySizedBox(
                      widthFactor: 0.65,
                      child: _Bone(height: 12, boneBase: boneBase),
                    ),

                    const Spacer(),

                    // Price
                    FractionallySizedBox(
                      widthFactor: 0.42,
                      child: _Bone(height: 16, boneBase: boneBase),
                    ),
                    const SizedBox(height: 8),

                    // Add-to-cart button (full width)
                    Row(
                      children: [
                        Expanded(
                          child: _Bone(
                            height: 30,
                            boneBase: boneBase,
                            borderRadius: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Shown in place of [_QuickChipsRow] while [ProductListingView._skeletonVisible]
/// [ProductListingSkeletonSliver] so both rows animate in visual lock-step.
class ProductListingChipsSkeleton extends StatefulWidget {
  const ProductListingChipsSkeleton({super.key});

  @override
  State<ProductListingChipsSkeleton> createState() =>
      _ProductListingChipsSkeletonState();
}

class _ProductListingChipsSkeletonState
    extends State<ProductListingChipsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  static const List<double> _chipWidths = [72, 50, 98, 82, 82, 95, 90];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boneBase = isDark
        ? AppColors.skeletonWithShimmerEffectDarkGrey
        : AppColors.skeletonWithShimmerEffectLightGrey;
    final boneHighlight = isDark
        ? AppColors.skeletonWithShimmerEffectDarkWhite
        : AppColors.skeletonWithShimmerEffectWhite;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final pos = -0.5 + _shimmer.value * 2.0;

        return SizedBox(
          height: 36,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                boneBase,
                boneBase,
                boneHighlight,
                boneBase,
                boneBase,
              ],
              stops: [
                0.0,
                (pos - 0.3).clamp(0.0, 1.0),
                pos.clamp(0.0, 1.0),
                (pos + 0.3).clamp(0.0, 1.0),
                1.0,
              ],
            ).createShader(bounds),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Non-interactive during skeleton phase
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (final w in _chipWidths) ...[
                    Container(
                      width: w,
                      height: 30,
                      decoration: BoxDecoration(
                        color: boneBase,
                        // Stadium border — identical to real ChoiceChip shape
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  final double height;
  final Color boneBase;
  final double borderRadius;

  const _Bone({
    required this.height,
    required this.boneBase,
    this.borderRadius = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: boneBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
