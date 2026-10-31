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
  String? discountPrice;
  String? originalPrice;
  int? discountPercentage;
  String? images;
  String? sku;
  int? stockQuantity;
  int? availableStock;
  bool? isInStock;
  bool? hasInsufficientStock;
  bool? isAvailable;

  CartDetailItem({
    this.id,
    this.productId,
    this.quantity,
    this.priceAtPurchase,
    this.name,
    this.price,
    this.discountPrice,
    this.originalPrice,
    this.discountPercentage,
    this.images,
    this.sku,
    this.stockQuantity,
    this.availableStock,
    this.isInStock,
    this.hasInsufficientStock,
    this.isAvailable,
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

    final pMap = json['product'] is Map ? (json['product'] as Map) : null;

    dynamic extractVal(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null && json[k].toString().trim().isNotEmpty) {
          return json[k];
        }
      }
      if (pMap != null) {
        for (final k in keys) {
          if (pMap.containsKey(k) && pMap[k] != null && pMap[k].toString().trim().isNotEmpty) {
            return pMap[k];
          }
        }
      }
      return null;
    }

    priceAtPurchase = (
      extractVal(['price_at_purchase', 'purchase_price']) ??
      extractVal(['price', 'unit_price']) ??
      ''
    ).toString();
    
    name = (
      extractVal(['name', 'product_name', 'title']) ??
      ''
    ).toString().trim();
    
    final rawBasePrice = extractVal(['price', 'regular_price', 'original_price', 'mrp', 'base_price']);
    final rawDiscountPrice = extractVal(['discount_price', 'discountPrice', 'discounted_price', 'offer_price', 'sale_price', 'special_price']);
    final rawPurchasePrice = extractVal(['price_at_purchase', 'purchase_price']);
    final rawUnit = extractVal(['unit_price', 'unitPrice']);

    final baseVal = double.tryParse((rawBasePrice ?? '').toString().trim());
    final discountVal = double.tryParse((rawDiscountPrice ?? '').toString().trim());
    final purchaseVal = double.tryParse((rawPurchasePrice ?? '').toString().trim());
    final unitVal = double.tryParse((rawUnit ?? '').toString().trim());

    double? resolvedPrice;
    double? resolvedOriginal;

    if (discountVal != null && discountVal > 0) {
      if (baseVal != null && discountVal < baseVal) {
        resolvedPrice = discountVal;
        resolvedOriginal = baseVal;
      } else {
        resolvedPrice = discountVal;
      }
    } else if (purchaseVal != null && purchaseVal > 0 && baseVal != null && purchaseVal < baseVal) {
      resolvedPrice = purchaseVal;
      resolvedOriginal = baseVal;
    } else if (unitVal != null && unitVal > 0 && baseVal != null && unitVal < baseVal) {
      resolvedPrice = unitVal;
      resolvedOriginal = baseVal;
    } else if (baseVal != null && baseVal > 0) {
      resolvedPrice = baseVal;
    } else if (purchaseVal != null && purchaseVal > 0) {
      resolvedPrice = purchaseVal;
    } else if (unitVal != null && unitVal > 0) {
      resolvedPrice = unitVal;
    }

    price = (resolvedPrice ?? 0.0).toString();
    originalPrice = resolvedOriginal?.toString();
    discountPrice = resolvedPrice != null && resolvedOriginal != null ? resolvedPrice.toString() : null;

    final rawDiscountPct = extractVal(['discount_percentage', 'discountPercentage', 'discount_percent']);
    discountPercentage = _toInt(rawDiscountPct);
    
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

    stockQuantity = _toInt(json['stock_quantity'] ?? json['stockQuantity'] ?? json['stock']);
    availableStock = _toInt(json['available_stock'] ?? json['stock_quantity'] ?? json['stock']);
    
    final rawInStock = json['isInStock'] ?? json['is_in_stock'];
    if (rawInStock is bool) {
      isInStock = rawInStock;
    } else if (rawInStock != null) {
      isInStock = rawInStock.toString() == '1' || rawInStock.toString() == 'true';
    } else if (availableStock != null) {
      isInStock = availableStock! > 0;
    }

    final rawInsufficient = json['has_insufficient_stock'];
    if (rawInsufficient is bool) {
      hasInsufficientStock = rawInsufficient;
    } else if (availableStock != null && quantity != null) {
      hasInsufficientStock = quantity! > availableStock!;
    }

    final rawAvailable = json['is_available'];
    if (rawAvailable is bool) {
      isAvailable = rawAvailable;
    } else {
      isAvailable = (isInStock != false) && (hasInsufficientStock != true);
    }
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
    out['stock_quantity'] = stockQuantity;
    out['available_stock'] = availableStock;
    out['isInStock'] = isInStock;
    out['is_in_stock'] = isInStock;
    out['has_insufficient_stock'] = hasInsufficientStock;
    out['is_available'] = isAvailable;
    return out;
  }

  bool get isOutOfStock =>
      (isInStock == false) ||
      (availableStock != null && availableStock! <= 0) ||
      (stockQuantity != null && stockQuantity! <= 0);
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
