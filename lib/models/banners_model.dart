class BannersModel {
  bool? success;
  List<BannerItemModel>? data;

  BannersModel({this.success, this.data});

  BannersModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <BannerItemModel>[];
      json['data'].forEach((v) {
        data!.add(BannerItemModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BannerItemModel {
  int? id;
  String? title;
  String? subtitle;
  String? description;
  String? image;
  String? buttonText;
  String? buttonLink;
  int? sortOrder;
  int? isActive;

  BannerItemModel({
    this.id,
    this.title,
    this.subtitle,
    this.description,
    this.image,
    this.buttonText,
    this.buttonLink,
    this.sortOrder,
    this.isActive,
  });

  BannerItemModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    title = json['title'];
    subtitle = json['subtitle'];
    description = json['description'];
    image = json['image'];
    buttonText = json['button_text'];
    buttonLink = json['button_link'];
    sortOrder = _parseInt(json['sort_order']);
    isActive = _parseInt(json['active']) ?? _parseInt(json['is_active']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['description'] = description;
    data['image'] = image;
    data['button_text'] = buttonText;
    data['button_link'] = buttonLink;
    data['sort_order'] = sortOrder;
    data['is_active'] = isActive;
    return data;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return double.tryParse(value)?.toInt();
    if (value is double) return value.toInt();
    return null;
  }
}
