class Cartdetail {
  bool? success;
  CartDetailData? data;

  Cartdetail({this.success, this.data});

  Cartdetail.fromJson(Map<String, dynamic> json) {
    success = json['success'] ?? true;
    
    final rawData = json['data'];
    if (rawData != null) {
      if (rawData is Map<String, dynamic>) {
        data = CartDetailData.fromJson(rawData);
      } else if (rawData is List) {
        // If data is directly a List of items, wrap it in CartDetailData
        data = CartDetailData(
          items: rawData
              .map((v) => CartDetailItem.fromJson(v as Map<String, dynamic>))
              .toList(),
        );
      }
    } else {
      // Check for other potential root-level keys containing the items list
      final alternativeItems = json['items'] ?? json['cart_items'] ?? json['cart'];
      if (alternativeItems is List) {
        data = CartDetailData(
          items: alternativeItems
              .map((v) => CartDetailItem.fromJson(v as Map<String, dynamic>))
              .toList(),
        );
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['success'] = success;
    if (data != null) {
      out['data'] = data!.toJson();
    }
    return out;
  }
}

class CartDetailData {
  int? cartId;
  int? userId;
  List<CartDetailItem>? items;
  int? totalItems;
  int? subtotal;

  CartDetailData({
    this.cartId,
    this.userId,
    this.items,
    this.totalItems,
    this.subtotal,
  });

  CartDetailData.fromJson(Map<String, dynamic> json) {
    cartId = _toInt(json['cart_id'] ?? json['id'] ?? json['cartId']);
    userId = _toInt(json['user_id'] ?? json['userId']);
    
    final itemsJson = json['items'] ?? json['cart_items'] ?? json['products'] ?? json['data'];
    if (itemsJson is List) {
      items = <CartDetailItem>[];
      for (final v in itemsJson) {
        if (v is Map<String, dynamic>) {
          items!.add(CartDetailItem.fromJson(v));
        }
      }
    }
    
    totalItems = _toInt(json['total_items'] ?? json['totalItems'] ?? json['total'] ?? json['count']);
    
    final subtotalVal = json['subtotal'] ?? json['total_price'] ?? json['subtotal_price'] ?? json['total'];
    if (subtotalVal != null) {
      if (subtotalVal is num) {
        subtotal = subtotalVal.toInt();
      } else {
        subtotal = double.tryParse(subtotalVal.toString())?.toInt();
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['cart_id'] = cartId;
    out['user_id'] = userId;
    if (items != null) {
      out['items'] = items!.map((v) => v.toJson()).toList();
    }
    out['total_items'] = totalItems;
    out['subtotal'] = subtotal;
    return out;
  }
}

class CartDetailItem {
  int? id;
  int? productId;
  int? quantity;
  String? priceAtPurchase;
  String? name;
  String? price;
  String? images;
  String? sku;

  CartDetailItem({
    this.id,
    this.productId,
    this.quantity,
    this.priceAtPurchase,
    this.name,
    this.price,
    this.images,
    this.sku,
  });

  CartDetailItem.fromJson(Map<String, dynamic> json) {
    id = _toInt(json['id'] ?? json['cart_item_id'] ?? json['item_id']);
    
    productId = _toInt(
      json['product_id'] ??
      json['productId'] ??
      (json['product'] is Map ? (json['product'] as Map)['id'] : null) ??
      json['id']
    );
    
    quantity = _toInt(json['quantity'] ?? json['qty'] ?? json['quantity_ordered'] ?? 1);
    
    priceAtPurchase = (
      json['price_at_purchase'] ??
      json['purchase_price'] ??
      json['price'] ??
      ''
    ).toString();
    
    name = (
      json['name'] ??
      json['product_name'] ??
      json['title'] ??
      (json['product'] is Map ? (json['product'] as Map)['name'] ?? (json['product'] as Map)['title'] : null) ??
      ''
    ).toString().trim();
    
    price = (
      json['price'] ??
      json['unit_price'] ??
      (json['product'] is Map ? (json['product'] as Map)['price'] : null) ??
      json['price_at_purchase'] ??
      ''
    ).toString();
    
    dynamic extractImg(Map<String, dynamic> j) {
      for (final k in ['images', 'image', 'imageUrl', 'product_image']) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v;
      }
      if (j['product'] is Map) {
        final p = j['product'] as Map;
        for (final k in ['images', 'image', 'imageUrl', 'product_image']) {
          final v = p[k];
          if (v != null && v.toString().trim().isNotEmpty) return v;
        }
      }
      return null;
    }
    
    final imgVal = extractImg(json);
    if (imgVal is List && imgVal.isNotEmpty) {
      images = imgVal.first.toString();
    } else {
      images = imgVal?.toString();
    }
    
    sku = (
      json['sku'] ??
      (json['product'] is Map ? (json['product'] as Map)['sku'] : null) ??
      ''
    ).toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['id'] = id;
    out['product_id'] = productId;
    out['quantity'] = quantity;
    out['price_at_purchase'] = priceAtPurchase;
    out['name'] = name;
    out['price'] = price;
    out['images'] = images;
    out['sku'] = sku;
    return out;
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
