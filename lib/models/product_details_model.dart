import 'dart:convert';
import 'package:flutter/foundation.dart';

class Productdetails {
  bool? success;
  Data? data;

  Productdetails({this.success, this.data});

  Productdetails.fromJson(Map<String, dynamic> json) {
    success = _asBool(json['success']);
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (['true', '1', 'yes', 'y'].contains(text)) return true;
    if (['false', '0', 'no', 'n'].contains(text)) return false;
    return null;
  }
}

class Data {
  int? id;
  String? name;
  String? slug;
  String? description;
  String? price;
  String? discountPrice;
  String? sku;
  int? stockQuantity;
  int? categoryId;
  List<String>? images;
  String? weight;
  int? isActive;
  String? createdAt;
  String? updatedAt;
  int? stock;
  String? attributes;
  String? categoryName;
  String? shortDescription;
  String? brand;
  String? unitLabel;
  bool? couponApplicable;
  int? discountPercentage;
  bool? isInStock;
  int? maxOrderQuantity;
  int? minOrderQuantity;
  String? estimatedDeliveryTime;
  DateTime? expiryDate;
  DateTime? manufacturingDate;
  String? countryOfOrigin;
  String? deliveryType;
  int? deliveryCharge;
  bool? freeDelivery;

  // New fields
  int? subcategoryId;
  int? parentCategoryId;
  String? parentCategoryName;
  String? childCategoryName;

  Data(
      {this.id,
      this.name,
      this.slug,
      this.description,
      this.price,
      this.discountPrice,
      this.sku,
      this.stockQuantity,
      this.categoryId,
      this.images,
      this.weight,
      this.isActive,
      this.createdAt,
      this.updatedAt,
      this.stock,
      this.attributes,
      this.categoryName,
      this.shortDescription,
      this.brand,
      this.unitLabel,
      this.couponApplicable,
      this.discountPercentage,
      this.isInStock,
      this.maxOrderQuantity,
      this.minOrderQuantity,
      this.estimatedDeliveryTime,
      this.expiryDate,
      this.manufacturingDate,
      this.countryOfOrigin,
      this.deliveryType,
      this.deliveryCharge,
      this.freeDelivery,
      this.subcategoryId,
      this.parentCategoryId,
      this.parentCategoryName,
      this.childCategoryName});

  Data.fromJson(Map<String, dynamic> json) {
    id = _asInt(json['id']);
    name = _asString(json['name']);
    slug = _asString(json['slug']);
    description = _asString(json['description']);
    price = _asString(json['price']);
    discountPrice = _asString(json['discount_price'] ?? json['discountPrice']);
    sku = _asString(json['sku']);
    stockQuantity = _asInt(json['stock_quantity'] ?? json['stockQuantity']);
    categoryId = _asInt(json['category_id'] ?? json['categoryId']);
    images = _asStringList(json['images']);
    weight = _asString(json['weight']);
    isActive = _asInt(json['is_active'] ?? json['isActive']);
    createdAt = _asString(json['created_at'] ?? json['createdAt']);
    updatedAt = _asString(json['updated_at'] ?? json['updatedAt']);
    stock = _asInt(json['stock']);
    attributes = _asString(json['attributes']);
    categoryName = _asString(json['category_name'] ?? json['categoryName']);
    shortDescription = _asString(
      json['short_description'] ?? json['shortDescription'],
    );
    brand = _asString(json['brand']);
    unitLabel = _asString(json['unit_label'] ?? json['unitLabel']);
    couponApplicable = _asBool(
      json['coupon_applicable'] ?? json['couponApplicable'],
    );
    discountPercentage = _asInt(
      json['discount_percentage'] ?? json['discountPercentage'],
    );
    isInStock = _asBool(json['is_in_stock'] ?? json['isInStock']);
    maxOrderQuantity = _asInt(
      json['max_order_quantity'] ?? json['maxOrderQuantity'],
    );
    minOrderQuantity = _asInt(
      json['min_order_quantity'] ?? json['minOrderQuantity'],
    );
    estimatedDeliveryTime = _asString(
      json['estimated_delivery_time'] ?? json['estimatedDeliveryTime'],
    );
    expiryDate = _asDateTime(json['expiry_date'] ?? json['expiryDate']);
    manufacturingDate = _asDateTime(
      json['manufacturing_date'] ?? json['manufacturingDate'],
    );
    countryOfOrigin = _asString(
      json['country_of_origin'] ?? json['countryOfOrigin'],
    );
    deliveryType = _asString(json['delivery_type'] ?? json['deliveryType']);
    deliveryCharge = _asInt(json['delivery_charge'] ?? json['deliveryCharge']);
    freeDelivery = _asBool(json['free_delivery'] ?? json['freeDelivery']);

    subcategoryId = _asInt(json['subcategory_id'] ?? json['subcategoryId']);
    parentCategoryId = _asInt(json['parent_category_id'] ?? json['parentCategoryId']);
    parentCategoryName = _asString(json['parent_category_name'] ?? json['parentCategoryName']);
    childCategoryName = _asString(json['child_category_name'] ?? json['childCategoryName']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['slug'] = this.slug;
    data['description'] = this.description;
    data['price'] = this.price;
    data['discount_price'] = this.discountPrice;
    data['sku'] = this.sku;
    data['stock_quantity'] = this.stockQuantity;
    data['category_id'] = this.categoryId;
    data['images'] = this.images;
    data['weight'] = this.weight;
    data['is_active'] = this.isActive;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['stock'] = this.stock;
    data['attributes'] = this.attributes;
    data['category_name'] = this.categoryName;
    data['short_description'] = this.shortDescription;
    data['brand'] = this.brand;
    data['unit_label'] = this.unitLabel;
    data['coupon_applicable'] = this.couponApplicable;
    data['discount_percentage'] = this.discountPercentage;
    data['is_in_stock'] = this.isInStock;
    data['max_order_quantity'] = this.maxOrderQuantity;
    data['min_order_quantity'] = this.minOrderQuantity;
    data['estimated_delivery_time'] = this.estimatedDeliveryTime;
    data['expiry_date'] =
        this.expiryDate != null ? this.expiryDate!.toIso8601String() : null;
    data['manufacturing_date'] = this.manufacturingDate != null
        ? this.manufacturingDate!.toIso8601String()
        : null;
    data['country_of_origin'] = this.countryOfOrigin;
    data['delivery_type'] = this.deliveryType;
    data['delivery_charge'] = this.deliveryCharge;
    data['free_delivery'] = this.freeDelivery;
    data['subcategory_id'] = this.subcategoryId;
    data['parent_category_id'] = this.parentCategoryId;
    data['parent_category_name'] = this.parentCategoryName;
    data['child_category_name'] = this.childCategoryName;
    return data;
  }

  static String? _asString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (['true', '1', 'yes', 'y'].contains(text)) return true;
    if (['false', '0', 'no', 'n'].contains(text)) return false;
    return null;
  }

  static List<String>? _asStringList(Object? value) {
    debugPrint('--- [DEBUG] _asStringList ---');
    debugPrint('value runtimeType: ${value.runtimeType}');
    debugPrint('value: $value');

    if (value is List) {
      final list = value.map((e) => e.toString()).toList();
      debugPrint('Parsed as List: $list');
      return list;
    }
    
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      
      // Try to parse if it's a JSON encoded list
      if (text.startsWith('[') && text.endsWith(']')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            final list = decoded.map((e) => e.toString()).toList();
            debugPrint('Parsed from JSON string: $list');
            return list;
          }
        } catch (_) {
          debugPrint('Failed to decode JSON string list');
        }
      }
      
      // Otherwise treat as a single string, maybe comma separated? Let's just return as single item list for now
      // Or split by comma or space
      if (text.contains(',') || text.contains(' ')) {
         final list = text.split(RegExp(r'[\s,]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
         debugPrint('Parsed from comma/space string: $list');
         return list;
      }
      
      debugPrint('Parsed as single string item');
      return [text];
    }
    return null;
  }


  static DateTime? _asDateTime(Object? value) {
    final text = _asString(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
