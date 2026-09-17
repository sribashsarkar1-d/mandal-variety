import 'package:flutter/foundation.dart';

import 'product_review_model.dart';

enum ProductCategory {
  grocery,
  beauty,
  shoes,
  fresh,
  snacks,
  drinks,
  dairy,
  tobacco,
  other,
}

extension ProductCategoryX on ProductCategory {
  String get displayName {
    switch (this) {
      case ProductCategory.grocery:
        return 'Grocery';
      case ProductCategory.beauty:
        return 'Beauty';
      case ProductCategory.shoes:
        return 'Shoes';
      case ProductCategory.fresh:
        return 'Fresh';
      case ProductCategory.snacks:
        return 'Snacks';
      case ProductCategory.drinks:
        return 'Drinks';
      case ProductCategory.dairy:
        return 'Dairy';
      case ProductCategory.tobacco:
        return 'Paan Corner';
      case ProductCategory.other:
        return 'Products';
    }
  }

  String get searchHint {
    switch (this) {
      case ProductCategory.grocery:
        return 'groceries';
      case ProductCategory.beauty:
        return 'beauty';
      case ProductCategory.shoes:
        return 'shoes';
      case ProductCategory.fresh:
        return 'fresh items';
      case ProductCategory.snacks:
        return 'snacks';
      case ProductCategory.drinks:
        return 'drinks';
      case ProductCategory.dairy:
        return 'dairy';
      case ProductCategory.tobacco:
        return 'tobacco products';
      case ProductCategory.other:
        return 'products';
    }
  }
}

@immutable
class ProductModel {
  final String id;
  final ProductCategory category;
  final String name;
  final String? shortDescription;
  final String imageUrl;
  final double price;
  final double? originalPrice;
  final String? discountTag;
  final int? discountPercentage;
  final double? rating;
  final int? reviewCount;
  final List<ProductReviewModel> reviews;
  final int? stockLeft;
  final bool? isFastDelivery;
  final bool? freeDelivery;
  final bool? isBestSeller;
  final String? categoryName;
  final int? categoryId;
  final int? parentCategoryId;
  final int? subcategoryId;

  const ProductModel({
    required this.id,
    required this.category,
    required this.name,
    this.shortDescription,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    this.discountTag,
    this.discountPercentage,
    this.rating,
    this.reviewCount,
    this.reviews = const [],
    this.stockLeft,
    this.isFastDelivery,
    this.freeDelivery,
    this.isBestSeller,
    this.categoryName,
    this.categoryId,
    this.parentCategoryId,
    this.subcategoryId,
  });

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price || discountTag != null;

  ProductModel copyWith({
    String? id,
    ProductCategory? category,
    String? name,
    String? shortDescription,
    String? imageUrl,
    double? price,
    double? originalPrice,
    String? discountTag,
    int? discountPercentage,
    double? rating,
    int? reviewCount,
    List<ProductReviewModel>? reviews,
    int? stockLeft,
    bool? isFastDelivery,
    bool? freeDelivery,
    bool? isBestSeller,
    String? categoryName,
    int? categoryId,
    int? parentCategoryId,
    int? subcategoryId,
  }) {
    return ProductModel(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      shortDescription: shortDescription ?? this.shortDescription,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountTag: discountTag ?? this.discountTag,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      reviews: reviews ?? this.reviews,
      stockLeft: stockLeft ?? this.stockLeft,
      isFastDelivery: isFastDelivery ?? this.isFastDelivery,
      freeDelivery: freeDelivery ?? this.freeDelivery,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
    );
  }
}
