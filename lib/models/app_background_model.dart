class AppBackgroundModel {
  bool? success;
  AppBackgroundData? data;

  AppBackgroundModel({this.success, this.data});

  AppBackgroundModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    data = json['data'] != null ? AppBackgroundData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class AppBackgroundData {
  int? id;
  String? image;
  String? imageUrl;
  String? title;
  int? status;
  String? createdAt;
  String? updatedAt;
  String? imageFullUrl;

  AppBackgroundData({
    this.id,
    this.image,
    this.imageUrl,
    this.title,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.imageFullUrl,
  });

  AppBackgroundData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    image = json['image'];
    imageUrl = json['image_url'];
    title = json['title'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    imageFullUrl = json['image_full_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['image'] = image;
    data['image_url'] = imageUrl;
    data['title'] = title;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['image_full_url'] = imageFullUrl;
    return data;
  }
}
