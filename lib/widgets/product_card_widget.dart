import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../common/snackbars/app_snackbar.dart';
import '../core/auth/auth_guard.dart';
import '../core/cart/cart_coordinator.dart';
import '../core/wishlist/wishlist_coordinator.dart';
import '../core/theme/app_colors.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/product_model.dart'; // To use ProductModel
import '../data/models/wishlist_item_model.dart';
import '../models/product_list_model.dart';

class ProductCardWidget extends StatefulWidget {
  const ProductCardWidget({
    super.key,
    required this.productId,
    this.product,
    required this.name,
    required this.priceText,
    this.oldPriceText,
    required this.categoryName,
    required this.imageUrl,
    this.discountBadgeText,
    this.rating,
    this.reviewCount,
    required this.onTap,
  });

  final int productId;
  final Data? product; // The raw API Data object, if available
  final String name;
  final String priceText;
  final String? oldPriceText;
  final String categoryName;
  final String imageUrl;
  final String? discountBadgeText;
  final double? rating;
  final int? reviewCount;
  final VoidCallback onTap;

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> {
  int _cartQuantity = 0;
  bool _isWishlisted = false;
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
      (e) => e?.productId == widget.productId.toString(),
      orElse: () => null,
    );
    final next = match?.quantity ?? 0;
    if (!mounted) return;
    if (_cartQuantity == next) return;
    setState(() => _cartQuantity = next);
  }

  void _syncWishlist(List<WishlistItemModel> items) {
    final next = items.any((item) => item.productId == widget.productId.toString());
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

    setState(() => _isCartActionLoading = true);
    try {
      final double unitPrice = double.tryParse(widget.priceText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      final result = await CartCoordinator.instance.addItem(
        CartItemModel(
          productId: widget.productId.toString(),
          name: widget.name,
          imageUrl: widget.imageUrl,
          unitPrice: unitPrice,
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
          widget.productId.toString(),
        );
      } else {
        final double unitPrice = double.tryParse(widget.priceText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        result = await WishlistCoordinator.instance.addItem(
          WishlistItemModel(
            productId: widget.productId.toString(),
            name: widget.name,
            imageUrl: widget.imageUrl,
            sku: null,
            unitPrice: unitPrice,
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
    
    Color getBadgeColor(String? text) {
      if (text == null) return const Color(0xFFFF3366);
      if (text.toLowerCase().contains('best')) return const Color(0xFF388E3C);
      return const Color(0xFFFF3366);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image and Badges
              Expanded(
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: widget.imageUrl.isEmpty
                            ? _fallbackImage(context)
                            : CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                                ),
                                errorWidget: (context, url, error) => _fallbackImage(context),
                              ),
                      ),
                    ),
                    // Discount Badge
                    if (widget.discountBadgeText != null && widget.discountBadgeText!.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: getBadgeColor(widget.discountBadgeText),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            widget.discountBadgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Wishlist Icon
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surface : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isWishlistActionLoading
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                                  color: _isWishlisted ? const Color(0xFFFF3366) : Colors.grey,
                                  size: 18,
                                ),
                                onPressed: _toggleWishlist,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Area
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Rating
                    if (widget.rating != null && widget.rating! > 0) ...[
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating!.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.reviewCount != null && widget.reviewCount! > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${widget.reviewCount})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    
                    // Price
                    Row(
                      children: [
                        Text(
                          widget.priceText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B5E20), // Dark Green
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.oldPriceText != null && widget.oldPriceText!.isNotEmpty)
                          Text(
                            widget.oldPriceText!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Category Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Light Green bg
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF546E7A), // Blue-grey text
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions Row
                    Row(
                      children: [
                        // Small Cart Add Button
                        InkWell(
                          onTap: _isCartActionLoading ? null : _handleAddToCart,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF388E3C), width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              color: Color(0xFF388E3C),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Main Add to Cart Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isCartActionLoading ? null : _handleAddToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon: _isCartActionLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.shopping_cart_outlined, size: 18),
                            label: const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
