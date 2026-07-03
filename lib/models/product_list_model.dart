class ProductList {
  bool? success;
  List<Data>? data;

  ProductList({this.success, this.data});

  ProductList.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  int? id;
  String? name;
  String? slug;
  String? description;
  double? price;
  double? discountPrice;
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
  Null? expiryDate;
  Null? manufacturingDate;
  String? countryOfOrigin;
  String? deliveryType;
  int? deliveryCharge;
  bool? freeDelivery;

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
      this.freeDelivery});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    slug = json['slug'];
    description = json['description'];
    
    // Parse price fields correctly
    price = _parseDouble(json['price']);
    discountPrice = _parseDouble(json['discount_price']);
    stockQuantity = _parseInt(json['stock_quantity']);
    categoryId = _parseInt(json['category_id']);
    isActive = _parseInt(json['is_active']);
    stock = _parseInt(json['stock']);
    discountPercentage = _parseInt(json['discountPercentage']);
    maxOrderQuantity = _parseInt(json['maxOrderQuantity']);
    minOrderQuantity = _parseInt(json['minOrderQuantity']);
    deliveryCharge = _parseInt(json['deliveryCharge']);
    
    sku = json['sku'];
    
    // Parse images, could be string or list
    if (json['images'] != null) {
      if (json['images'] is String) {
        images = [json['images']];
      } else if (json['images'] is List) {
        images = json['images'].cast<String>();
      }
    }
    
    weight = json['weight']?.toString();
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    attributes = json['attributes'];
    categoryName = json['category_name'];
    shortDescription = json['shortDescription'];
    brand = json['brand'];
    unitLabel = json['unitLabel'];
    
    // Parse booleans safely
    couponApplicable = _parseBool(json['couponApplicable']);
    isInStock = _parseBool(json['isInStock']);
    freeDelivery = _parseBool(json['freeDelivery']);
    
    estimatedDeliveryTime = json['estimatedDeliveryTime'];
    expiryDate = json['expiryDate'];
    manufacturingDate = json['manufacturingDate'];
    countryOfOrigin = json['countryOfOrigin'];
    deliveryType = json['deliveryType'];
  }
  
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return double.tryParse(value)?.toInt();
    if (value is double) return value.toInt();
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return null;
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
    data['shortDescription'] = this.shortDescription;
    data['brand'] = this.brand;
    data['unitLabel'] = this.unitLabel;
    data['couponApplicable'] = this.couponApplicable;
    data['discountPercentage'] = this.discountPercentage;
    data['isInStock'] = this.isInStock;
    data['maxOrderQuantity'] = this.maxOrderQuantity;
    data['minOrderQuantity'] = this.minOrderQuantity;
    data['estimatedDeliveryTime'] = this.estimatedDeliveryTime;
    data['expiryDate'] = this.expiryDate;
    data['manufacturingDate'] = this.manufacturingDate;
    data['countryOfOrigin'] = this.countryOfOrigin;
    data['deliveryType'] = this.deliveryType;
    data['deliveryCharge'] = this.deliveryCharge;
    data['freeDelivery'] = this.freeDelivery;
    return data;
  }
}
