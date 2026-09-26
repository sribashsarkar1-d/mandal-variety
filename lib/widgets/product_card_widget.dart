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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image and Badges
              Expanded(
                flex: 5, // Give more priority to the image
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: widget.imageUrl.isEmpty
                            ? _fallbackImage(context)
                            : CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.contain, // Show full image without cropping
                                placeholder: (context, url) => Container(
                                  color: isDark ? Colors.grey[800] : Colors.grey[100],
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getBadgeColor(widget.discountBadgeText),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            widget.discountBadgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
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
                        width: 28,
                        height: 28,
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
                                padding: EdgeInsets.all(6.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                                  color: _isWishlisted ? const Color(0xFFFF3366) : Colors.grey,
                                  size: 16,
                                ),
                                onPressed: _toggleWishlist,
                              ),
                      ),
                    ),
                    // Rating overlay on image
                    if (widget.rating != null && widget.rating! > 0)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                widget.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (widget.reviewCount != null && widget.reviewCount! > 0) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '(${widget.reviewCount})',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content Area
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                          const SizedBox(height: 4),
                          
                          // Price Row
                          Row(
                            children: [
                              Text(
                                widget.priceText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF008B4C), // Green color matching screenshot
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (widget.oldPriceText != null && widget.oldPriceText!.isNotEmpty)
                                Text(
                                  widget.oldPriceText!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Category Pill with Leaf Icon
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : const Color(0xFFF1F8E9), // Light greenish-grey
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.eco, size: 12, color: Color(0xFF388E3C)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF424242),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Full-width Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _isCartActionLoading ? null : _handleAddToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008B4C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: _isCartActionLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.shopping_cart_outlined, size: 16),
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
