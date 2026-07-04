class Cartadd {
  bool? success;
  String? message;
  Data? data;

  Cartadd({this.success, this.message, this.data});

  Cartadd.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  int? cartId;
  int? cartItemId;
  int? productId;
  int? quantity;

  Data({this.cartId, this.cartItemId, this.productId, this.quantity});

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  Data.fromJson(Map<String, dynamic> json) {
    cartId = _parseInt(json['cart_id']);
    cartItemId = _parseInt(json['cart_item_id']);
    productId = _parseInt(json['product_id']);
    quantity = _parseInt(json['quantity']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['cart_id'] = cartId;
    data['cart_item_id'] = cartItemId;
    data['product_id'] = productId;
    data['quantity'] = quantity;
    return data;
  }
}
