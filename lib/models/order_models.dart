typedef OrdersListResponse = OrderList;
typedef OrderListItem = Orders;
typedef OrderDetailResponse = OrderDetails;
typedef CancelOrderResponse = OrderCencel;
typedef CreateOrderResponse = OrderCreate;
typedef OrderDetailItem = Items;

class OrderList {
  bool? success;
  OrderListData? data;
  String? message;

  OrderList({this.success, this.data, this.message});

  OrderList.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message']?.toString();
    data = json['data'] != null ? OrderListData.fromJson(json['data'] as Map<String, dynamic>) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['success'] = success;
    out['message'] = message;
    if (data != null) {
      out['data'] = data!.toJson();
    }
    return out;
  }
}

class OrderListData {
  int? userId;
  List<Orders>? orders;
  int? totalOrders;

  OrderListData({this.userId, this.orders, this.totalOrders});

  OrderListData.fromJson(Map<String, dynamic> json) {
    userId = _toInt(json['user_id']);
    if (json['orders'] != null) {
      orders = <Orders>[];
      json['orders'].forEach((v) {
        orders!.add(Orders.fromJson(v as Map<String, dynamic>));
      });
    }
    totalOrders = _toInt(json['total_orders']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['user_id'] = userId;
    if (orders != null) {
      out['orders'] = orders!.map((v) => v.toJson()).toList();
    }
    out['total_orders'] = totalOrders;
    return out;
  }
}

class Orders {
  int? id;
  int? userId;
  String? orderNumber;
  String? _totalAmountRaw;
  String? deliveryCharge;
  String? taxAmount;
  String? grandTotal;
  String? status;
  String? paymentStatus;
  String? deliveryAddress;
  String? pincode;
  dynamic deliveryEta;
  dynamic assignedDeliveryId;
  dynamic notes;
  String? _createdAtRaw;
  String? updatedAt;
  String? trackingStatus;
  String? adminRemark;
  String? orderStatus;

  // Compatibility fields
  List<Items>? items;

  Orders({
    this.id,
    this.userId,
    this.orderNumber,
    String? totalAmount,
    this.deliveryCharge,
    this.taxAmount,
    this.grandTotal,
    this.status,
    this.paymentStatus,
    this.deliveryAddress,
    this.pincode,
    this.deliveryEta,
    this.assignedDeliveryId,
    this.notes,
    String? createdAt,
    this.updatedAt,
    this.trackingStatus,
    this.adminRemark,
    this.orderStatus,
    this.items,
  }) : _totalAmountRaw = totalAmount,
       _createdAtRaw = createdAt;

  Orders.fromJson(Map<String, dynamic> json) {
    id = _toInt(json['id']);
    userId = _toInt(json['user_id']);
    orderNumber = json['order_number']?.toString();
    _totalAmountRaw = json['total_amount']?.toString();
    deliveryCharge = json['delivery_charge']?.toString();
    taxAmount = json['tax_amount']?.toString();
    grandTotal = json['grand_total']?.toString();
    status = json['status']?.toString();
    paymentStatus = json['payment_status']?.toString();
    deliveryAddress = json['delivery_address']?.toString();
    pincode = json['pincode']?.toString();
    deliveryEta = json['delivery_eta'];
    assignedDeliveryId = json['assigned_delivery_id'];
    notes = json['notes'];
    _createdAtRaw = json['created_at']?.toString();
    updatedAt = json['updated_at']?.toString();
    trackingStatus = json['tracking_status']?.toString();
    adminRemark = json['admin_remark']?.toString();
    orderStatus = json['order_status']?.toString();

    // Parse items if present
    final rawItems = json['items'] ?? json['products'] ?? json['order_items'];
    if (rawItems is List) {
      items = rawItems
          .map((v) => Items.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['id'] = id;
    out['user_id'] = userId;
    out['order_number'] = orderNumber;
    out['total_amount'] = _totalAmountRaw;
    out['delivery_charge'] = deliveryCharge;
    out['tax_amount'] = taxAmount;
    out['grand_total'] = grandTotal;
    out['status'] = status;
    out['payment_status'] = paymentStatus;
    out['delivery_address'] = deliveryAddress;
    out['pincode'] = pincode;
    out['delivery_eta'] = deliveryEta;
    out['assigned_delivery_id'] = assignedDeliveryId;
    out['notes'] = notes;
    out['created_at'] = _createdAtRaw;
    out['updated_at'] = updatedAt;
    out['tracking_status'] = trackingStatus;
    out['admin_remark'] = adminRemark;
    out['order_status'] = orderStatus;
    if (items != null) {
      out['items'] = items!.map((v) => v.toJson()).toList();
    }
    return out;
  }

  // Compatibility Getters
  int? get orderId => id;
  String? get address => deliveryAddress;
  String? get paymentMethod => 'Cash on Delivery';
  double? get subtotal => double.tryParse(_totalAmountRaw ?? '0.0') ?? 0.0;
  double? get deliveryChargeDouble => 10.0;
  double? get taxAmountDouble => 0.0;
  double? get grandTotalDouble => double.tryParse(grandTotal ?? '0.0') ?? 0.0;
  double? get totalAmount => (subtotal ?? 0.0) + 10.0;
  DateTime? get createdAt => _createdAtRaw != null ? DateTime.tryParse(_createdAtRaw!) : null;
}

class OrderDetails {
  bool? success;
  OrderDetailData? data;

  OrderDetails({this.success, this.data});

  OrderDetails.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    data = json['data'] != null ? OrderDetailData.fromJson(json['data'] as Map<String, dynamic>) : null;
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

class OrderDetailData extends Orders {
  String? deliveryName;

  OrderDetailData({
    super.id,
    super.userId,
    super.orderNumber,
    super.totalAmount,
    super.deliveryCharge,
    super.taxAmount,
    super.grandTotal,
    super.status,
    super.paymentStatus,
    super.deliveryAddress,
    super.pincode,
    super.deliveryEta,
    super.assignedDeliveryId,
    super.notes,
    super.createdAt,
    super.updatedAt,
    super.trackingStatus,
    super.adminRemark,
    super.orderStatus,
    this.deliveryName,
    super.items,
  });

  OrderDetailData.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    deliveryName = json['delivery_name']?.toString();
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = super.toJson();
    data['delivery_name'] = deliveryName;
    return data;
  }
}

class Items {
  int? id;
  int? orderId;
  int? productId;
  int? quantity;
  String? _priceRaw;
  String? name;
  String? images;

  Items({
    this.id,
    this.orderId,
    this.productId,
    this.quantity,
    String? price,
    this.name,
    this.images,
  }) : _priceRaw = price;

  Items.fromJson(Map<String, dynamic> json) {
    id = _toInt(json['id']);
    orderId = _toInt(json['order_id']);
    productId = _toInt(json['product_id']);
    quantity = _toInt(json['quantity']);
    _priceRaw = json['price']?.toString();
    name = json['name']?.toString();
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
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['order_id'] = orderId;
    data['product_id'] = productId;
    data['quantity'] = quantity;
    data['price'] = _priceRaw;
    data['name'] = name;
    data['images'] = images;
    return data;
  }

  // Compatibility Getters
  String? get productName => name;
  double? get price => double.tryParse(_priceRaw ?? '0.0');
}

class OrderCencel {
  bool? success;
  String? message;

  OrderCencel({this.success, this.message});

  OrderCencel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['success'] = success;
    out['message'] = message;
    return out;
  }
}

class OrderCreate {
  bool? success;
  String? message;
  OrderCreateData? data;

  OrderCreate({this.success, this.message, this.data});

  OrderCreate.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message']?.toString();
    data = json['data'] != null ? OrderCreateData.fromJson(json['data'] as Map<String, dynamic>) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['success'] = success;
    out['message'] = message;
    if (data != null) {
      out['data'] = data!.toJson();
    }
    return out;
  }

  // Compatibility Getter
  int? get orderId => data?.orderId != null ? int.tryParse(data!.orderId!) : null;
}

class OrderCreateData {
  String? orderId;
  String? orderNumber;
  double? grandTotal;

  OrderCreateData({this.orderId, this.orderNumber, this.grandTotal});

  OrderCreateData.fromJson(Map<String, dynamic> json) {
    orderId = json['order_id']?.toString();
    orderNumber = json['order_number']?.toString();
    grandTotal = _toDouble(json['grand_total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    out['order_id'] = orderId;
    out['order_number'] = orderNumber;
    out['grand_total'] = grandTotal;
    return out;
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
