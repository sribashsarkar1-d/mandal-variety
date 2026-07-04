class Wishlistlist {
  bool? success;
  WishlistData? data;

  Wishlistlist({this.success, this.data});

  Wishlistlist.fromJson(Map<String, dynamic> json) {
    success = _asBool(json['success']) ?? true;
    
    final rawData = json['data'];
    if (rawData != null) {
      if (rawData is Map<String, dynamic>) {
        data = WishlistData.fromJson(rawData);
      } else if (rawData is List) {
        data = WishlistData(
          items: rawData
              .map((v) => WishlistItem.fromJson(v as Map<String, dynamic>))
              .toList(),
        );
      }
    } else {
      final alternativeItems = json['items'] ?? json['wishlist_items'] ?? json['wishlist'];
      if (alternativeItems is List) {
        data = WishlistData(
          items: alternativeItems
              .map((v) => WishlistItem.fromJson(v as Map<String, dynamic>))
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

class WishlistData {
  int? userId;
  List<WishlistItem>? items;
  int? totalItems;

  WishlistData({this.userId, this.items, this.totalItems});

  WishlistData.fromJson(Map<String, dynamic> json) {
    userId = _toInt(json['user_id'] ?? json['userId']);
    
    final itemsJson = json['items'] ?? json['wishlist_items'] ?? json['products'] ?? json['data'];
    if (itemsJson is List) {
      items = <WishlistItem>[];
      for (final v in itemsJson) {
        if (v is Map<String, dynamic>) {
          items!.add(WishlistItem.fromJson(v));
        }
      }
    } else {
      items = <WishlistItem>[];
    }
    
    totalItems = _toInt(json['total_items'] ?? json['totalItems'] ?? json['total'] ?? json['count']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['user_id'] = userId;
    if (items != null) {
      out['items'] = items!.map((v) => v.toJson()).toList();
    }
    out['total_items'] = totalItems;
    return out;
  }
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

class WishlistItem {
  int? id;
  int? productId;
  String? createdAt;
  String? name;
  String? price;
  String? images;
  String? sku;

  WishlistItem({
    this.id,
    this.productId,
    this.createdAt,
    this.name,
    this.price,
    this.images,
    this.sku,
  });

  WishlistItem.fromJson(Map<String, dynamic> json) {
    id = _toInt(json['id'] ?? json['wishlist_item_id'] ?? json['item_id']);
    
    productId = _toInt(
      json['product_id'] ??
      json['productId'] ??
      (json['product'] is Map ? (json['product'] as Map)['id'] : null) ??
      json['id']
    );
    
    createdAt = (json['created_at'] ?? '').toString();
    
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
    out['created_at'] = createdAt;
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
