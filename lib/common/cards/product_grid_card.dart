import 'package:flutter/material.dart';

import '../../core/utils/app_currency.dart';
import '../../data/models/product_model.dart';
import '../../widgets/product_card_widget.dart';

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
          childAspectRatio: 0.65, // Updated to match home screen
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

class ProductGridCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductGridCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = AppCurrency.format(product.price, freeForZero: false);
    
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.price;
    final oldPriceText = hasDiscount ? AppCurrency.format(product.originalPrice!, freeForZero: false) : null;
    
    String? discountBadgeText;
    if (product.discountTag != null && product.discountTag!.isNotEmpty) {
      discountBadgeText = product.discountTag;
    } else if ((product.discountPercentage ?? 0) > 0) {
      discountBadgeText = '${product.discountPercentage}% OFF';
    } else if (hasDiscount) {
      final p = (((product.originalPrice! - product.price) / product.originalPrice!) * 100).round();
      if (p > 0) discountBadgeText = '$p% OFF';
    }

    final categoryName = product.categoryName?.trim().isNotEmpty == true 
        ? product.categoryName!.trim() 
        : product.category.displayName;

    return ProductCardWidget(
      productId: int.tryParse(product.id) ?? 0,
      name: product.name.trim().isEmpty ? 'Unnamed Product' : product.name.trim(),
      priceText: priceText,
      oldPriceText: oldPriceText,
      categoryName: categoryName,
      imageUrl: product.imageUrl,
      discountBadgeText: discountBadgeText,
      rating: product.rating,
      reviewCount: product.reviewCount,
      onTap: onTap ?? () {},
    );
  }
}
