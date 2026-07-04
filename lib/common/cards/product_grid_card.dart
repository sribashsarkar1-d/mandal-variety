import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../snackbars/app_snackbar.dart';
import '../../core/auth/auth_guard.dart';
import '../../core/cart/cart_coordinator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../core/wishlist/wishlist_coordinator.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/wishlist_item_model.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = source.trim();
  if (value.isEmpty) {
    return const AssetImage(_fallbackImageAsset);
  }
  if (value.startsWith('assets/')) {
    return AssetImage(value);
  }
  if (_isHttpUrl(value)) {
    return NetworkImage(value);
  }
  return const AssetImage(_fallbackImageAsset);
}

class ProductGridSliver extends StatelessWidget {
  final List<ProductModel> products;
  final EdgeInsetsGeometry padding;
  final ValueChanged<ProductModel>? onProductTap;

  const ProductGridSliver({
    super.key,
    required this.products,
    this.onProductTap,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.58,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final p = products[index];
          return ProductGridCard(
            key: ValueKey(p.id),
            product: p,
            onTap: onProductTap == null ? null : () => onProductTap!.call(p),
          );
        }, childCount: products.length),
      ),
    );
  }
}

class ProductGridCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductGridCard({super.key, required this.product, this.onTap});

  @override
  State<ProductGridCard> createState() => _ProductGridCardState();
}

class _ProductGridCardState extends State<ProductGridCard> {
  int _cartQuantity = 0;
  bool _isWishlisted = false;
  bool _justAddedPulse = false;
  bool _isCartActionLoading = false;
  bool _isWishlistActionLoading = false;

  late final Stream<List<CartItemModel>> _cartStream;
  late final StreamSubscription<List<CartItemModel>> _cartSub;
  late final Stream<List<WishlistItemModel>> _wishlistStream;
  late final StreamSubscription<List<WishlistItemModel>> _wishlistSub;

  @override
  void initState() {
    super.initState();
    _cartStream = CartCoordinator.instance.watchItems();
    _cartSub = _cartStream.listen(_syncCartQty);
    CartCoordinator.instance.getItems().then(_syncCartQty);

    _wishlistStream = WishlistCoordinator.instance.watchItems();
    _wishlistSub = _wishlistStream.listen(_syncWishlist);
    WishlistCoordinator.instance.getItems().then(_syncWishlist);
  }

  void _syncCartQty(List<CartItemModel> items) {
    final match = items.cast<CartItemModel?>().firstWhere(
      (e) => e?.productId == widget.product.id,
      orElse: () => null,
    );
    final next = match?.quantity ?? 0;
    if (!mounted) return;
    if (_cartQuantity == next) return;
    setState(() => _cartQuantity = next);
  }

  void _syncWishlist(List<WishlistItemModel> items) {
    final next = items.any((item) => item.productId == widget.product.id);
    if (!mounted || _isWishlisted == next) return;
    setState(() => _isWishlisted = next);
  }

  @override
  void dispose() {
    _cartSub.cancel();
    _wishlistSub.cancel();
    super.dispose();
  }

  Future<void> _handleAddToCart() async {
    if (_cartQuantity > 0 || _isCartActionLoading) return;
    final allowed = await handleProtectedAction(context);
    if (!allowed || !mounted) return;

    HapticFeedback.lightImpact();
    _pulseAdded();

    setState(() => _isCartActionLoading = true);
    try {
      final result = await CartCoordinator.instance.addItem(
        CartItemModel(
          productId: widget.product.id,
          name: widget.product.name,
          imageUrl: widget.product.imageUrl,
          unitPrice: widget.product.price,
          quantity: 1,
        ),
      );
      if (!mounted) return;
      if (result.success) {
        AppSnackbar.success(context, result.message);
      } else {
        AppSnackbar.warning(context, result.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isCartActionLoading = false);
      }
    }
  }

  Future<void> _increment() async {
    if (_isCartActionLoading) return;
    final allowed = await handleProtectedAction(context);
    if (!allowed || !mounted) return;

    HapticFeedback.selectionClick();

    setState(() => _isCartActionLoading = true);
    try {
      await CartCoordinator.instance.setQuantity(
        widget.product.id,
        _cartQuantity + 1,
      );
    } finally {
      if (mounted) {
        setState(() => _isCartActionLoading = false);
      }
    }
  }

  Future<void> _decrement() async {
    if (_isCartActionLoading) return;
    final allowed = await handleProtectedAction(context);
    if (!allowed || !mounted) return;

    HapticFeedback.selectionClick();
    setState(() => _isCartActionLoading = true);
    if (_cartQuantity <= 1) {
      try {
        await CartCoordinator.instance.removeItem(widget.product.id);
      } finally {
        if (mounted) {
          setState(() => _isCartActionLoading = false);
        }
      }
      return;
    }
    try {
      await CartCoordinator.instance.setQuantity(
        widget.product.id,
        _cartQuantity - 1,
      );
    } finally {
      if (mounted) {
        setState(() => _isCartActionLoading = false);
      }
    }
  }

  void _pulseAdded() {
    if (!mounted) return;
    setState(() => _justAddedPulse = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _justAddedPulse = false);
    });
  }

  Future<void> _toggleWishlist() async {
    if (_isWishlistActionLoading) return;
    final allowed = await handleProtectedAction(context);
    if (!allowed || !mounted) return;

    HapticFeedback.heavyImpact();
    setState(() => _isWishlistActionLoading = true);
    try {
      late final WishlistActionResult result;
      if (_isWishlisted) {
        result = await WishlistCoordinator.instance.removeItem(
          widget.product.id,
        );
      } else {
        result = await WishlistCoordinator.instance.addItem(
          WishlistItemModel(
            productId: widget.product.id,
            name: widget.product.name,
            imageUrl: widget.product.imageUrl,
            sku: null,
            unitPrice: widget.product.price,
          ),
        );
      }

      if (!mounted) return;
      if (result.success) {
        AppSnackbar.success(context, result.message);
      } else {
        AppSnackbar.warning(context, result.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isWishlistActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final discountBase = isDark ? AppColors.darkError : AppColors.lightError;
    final discountBg = discountBase.withValues(alpha: 0.92);
    final wishlistActive = discountBase;
    final warning = isDark ? AppColors.darkWarning : AppColors.lightWarning;
    final fastDeliveryAccent = isDark
        ? AppColors.darkSuccess
        : AppColors.lightSuccess;
    final fastDeliveryBg = theme.colorScheme.surface.withValues(alpha: 0.86);

    final hasDiscount =
        widget.product.originalPrice != null &&
        widget.product.originalPrice! > widget.product.price;
    final discountTag =
      (widget.product.discountTag ?? '').trim().isNotEmpty
      ? widget.product.discountTag!.trim()
      : _deriveDiscountTag(widget.product);
    final shortDescription = (widget.product.shortDescription ?? '').trim();

    final rating = widget.product.rating;
    final reviewCount = widget.product.reviewCount;

    final cardBase = theme.colorScheme.surfaceContainerHighest;
    final cardRadius = BorderRadius.circular(20);
    final cardBorder = theme.colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.30 : 0.75,
    );
    final inCartBorder = theme.primaryColor.withValues(alpha: 0.55);

    final inCartBg = Color.alphaBlend(
      theme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.10),
      cardBase,
    );

    final bool inCart = _cartQuantity > 0;

    final bool showLowStock =
        widget.product.stockLeft != null && widget.product.stockLeft! <= 5;
    final bool showFastDelivery = widget.product.isFastDelivery == true;
    final bool showFreeDelivery = widget.product.freeDelivery == true;
    final int nameMaxLines = (rating != null && showLowStock) ? 1 : 2;

    Widget tagPill({
      required String text,
      required Color background,
      required Color foreground,
      Color? border,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
    }) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border, width: 1),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return AnimatedScale(
      scale: _justAddedPulse ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: inCart ? inCartBg : cardBase,
        elevation: isDark ? 1.2 : 2.0,
        shadowColor: theme.shadowColor.withValues(alpha: isDark ? 0.55 : 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: inCart ? inCartBorder : cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.08,
                      child: Image(
                        image: _resolveImageProvider(widget.product.imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.disabledColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (discountTag != null)
                                tagPill(
                                  text: discountTag,
                                  background: discountBg,
                                  foreground: theme.colorScheme.onError,
                                ),
                              const Spacer(),
                              Material(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.80,
                                ),
                                shape: const CircleBorder(),
                                child: InkResponse(
                                  onTap: _isWishlistActionLoading
                                      ? null
                                      : () => _toggleWishlist(),
                                  radius: 20,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      _isWishlisted
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 18,
                                      color: _isWishlisted
                                          ? wishlistActive
                                          : onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (showFastDelivery || showFreeDelivery)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  if (showFreeDelivery)
                                    tagPill(
                                      text: 'Free Delivery',
                                      background: fastDeliveryBg,
                                      foreground: theme.primaryColor,
                                      border: theme.primaryColor.withValues(
                                        alpha: 0.55,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  if (showFastDelivery)
                                    tagPill(
                                      text: 'Fast Delivery',
                                      background: fastDeliveryBg,
                                      foreground: fastDeliveryAccent,
                                      border: fastDeliveryAccent.withValues(
                                        alpha: 0.55,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        maxLines: nameMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),

                      if (rating != null)
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: warning),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            if (reviewCount != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (showLowStock) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Only ${widget.product.stockLeft} left',
                          style: AppTextStyles.caption.copyWith(
                            color: discountBase,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final ctaMaxWidth = (constraints.maxWidth * 0.48)
                              .clamp(76.0, 164.0);
                          final bool compactCta = ctaMaxWidth <= 112;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppCurrency.format(widget.product.price, freeForZero: false),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                        height: 1.05,
                                      ),
                                    ),
                                    if (hasDiscount)
                                      Text(
                                        AppCurrency.format(
                                          widget.product.originalPrice!,
                                          freeForZero: false,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption.copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: theme.disabledColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: ctaMaxWidth,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: inCart
                                      ? _CartQuantityStepper(
                                          quantity: _cartQuantity,
                                          onDecrement: _decrement,
                                          onIncrement: _increment,
                                          compact: compactCta,
                                        )
                                      : _AddToCartButton(
                                          onTap: _handleAddToCart,
                                          compact: compactCta,
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _deriveDiscountTag(ProductModel product) {
    if ((product.discountPercentage ?? 0) > 0) {
      return '${product.discountPercentage}% OFF';
    }

    final original = product.originalPrice;
    if (original == null || original <= product.price || original <= 0) {
      return null;
    }

    final percentage = (((original - product.price) / original) * 100).round();
    if (percentage <= 0) return null;
    return '$percentage% OFF';
  }
}

class _AddToCartButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _AddToCartButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: theme.primaryColor,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: compact
              ? const EdgeInsets.all(10)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_grocery_store_outlined,
                color: theme.colorScheme.onPrimary,
                size: 18,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  'Add to Cart',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CartQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool compact;

  const _CartQuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = theme.colorScheme.surface;
    final border = theme.dividerColor.withValues(alpha: isDark ? 0.40 : 0.55);
    final onSurface = theme.colorScheme.onSurface;

    Widget iconBtn({required IconData icon, required VoidCallback onTap}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : 8),
            child: Icon(icon, size: 18, color: onSurface),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconBtn(icon: Icons.remove, onTap: onDecrement),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            child: Text(
              quantity.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          iconBtn(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}
