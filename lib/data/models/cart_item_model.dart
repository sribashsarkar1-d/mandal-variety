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
  final int quantity;
  final int? maxQuantity;

  const CartItemModel({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.maxQuantity,
    this.imageUrl,
  });

  CartItemModel copyWith({
    String? productId,
    String? name,
    String? imageUrl,
    double? unitPrice,
    int? quantity,
    int? maxQuantity,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
    };
  }

  static CartItemModel fromJson(Map<String, dynamic> json) {
    final rawPrice = json['unitPrice'];
    final rawQty = json['quantity'];
    final rawMax = json['maxQuantity'];

    return CartItemModel(
      productId: (json['productId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      unitPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0,
      quantity: rawQty is int
          ? rawQty
          : int.tryParse(rawQty?.toString() ?? '') ?? 1,
      maxQuantity: rawMax is int
          ? rawMax
          : int.tryParse(rawMax?.toString() ?? ''),
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
