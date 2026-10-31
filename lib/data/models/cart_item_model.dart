import 'dart:convert';

/// Cart item model persisted locally (Hive) via repository.
///
/// Stored as JSON to keep persistence simple and easily replaceable with an API
/// without changing UI logic.
class CartItemModel {
  final String productId;
  final String name;
  final String? imageUrl;
  final double unitPrice;
  final double? originalPrice;
  final String? discountTag;
  final int quantity;
  final int? maxQuantity;
  final int? availableStock;
  final bool? isInStock;

  const CartItemModel({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.originalPrice,
    this.discountTag,
    required this.quantity,
    this.maxQuantity,
    this.imageUrl,
    this.availableStock,
    this.isInStock,
  });

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > unitPrice;

  bool get isOutOfStock =>
      (isInStock == false) ||
      (availableStock != null && availableStock! <= 0);

  bool get hasInsufficientStock =>
      !isOutOfStock &&
      availableStock != null &&
      quantity > availableStock!;

  bool get isAvailable => !isOutOfStock && !hasInsufficientStock;

  CartItemModel copyWith({
    String? productId,
    String? name,
    String? imageUrl,
    double? unitPrice,
    double? originalPrice,
    String? discountTag,
    int? quantity,
    int? maxQuantity,
    int? availableStock,
    bool? isInStock,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      unitPrice: unitPrice ?? this.unitPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      discountTag: discountTag ?? this.discountTag,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      availableStock: availableStock ?? this.availableStock,
      isInStock: isInStock ?? this.isInStock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'originalPrice': originalPrice,
      'discountTag': discountTag,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
      'availableStock': availableStock,
      'isInStock': isInStock,
    };
  }

  static CartItemModel fromJson(Map<String, dynamic> json) {
    final rawPrice = json['unitPrice'] ?? json['price'];
    final rawOriginal = json['originalPrice'] ?? json['original_price'];
    final rawTag = json['discountTag'] ?? json['discount_tag'];
    final rawQty = json['quantity'];
    final rawMax = json['maxQuantity'];
    final rawStock = json['availableStock'] ?? json['stock_quantity'] ?? json['stock'];
    final rawInStock = json['isInStock'] ?? json['is_in_stock'];

    final parsedPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;

    final parsedOriginal = rawOriginal is num
        ? rawOriginal.toDouble()
        : double.tryParse(rawOriginal?.toString() ?? '');

    return CartItemModel(
      productId: (json['productId'] ?? json['product_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      unitPrice: parsedPrice,
      originalPrice: parsedOriginal,
      discountTag: rawTag?.toString(),
      quantity: rawQty is int
          ? rawQty
          : int.tryParse(rawQty?.toString() ?? '') ?? 1,
      maxQuantity: rawMax is int
          ? rawMax
          : int.tryParse(rawMax?.toString() ?? ''),
      availableStock: rawStock is int
          ? rawStock
          : int.tryParse(rawStock?.toString() ?? ''),
      isInStock: rawInStock is bool
          ? rawInStock
          : (rawInStock != null ? rawInStock.toString() == '1' || rawInStock.toString() == 'true' : null),
    );
  }

  static List<CartItemModel> decodeList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<CartItemModel> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
  }
}
