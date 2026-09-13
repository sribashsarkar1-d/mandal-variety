class CategoryHierarchyModel {
  bool? success;
  List<HierarchyParentModel>? data;

  CategoryHierarchyModel({this.success, this.data});

  CategoryHierarchyModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <HierarchyParentModel>[];
      json['data'].forEach((v) {
        data!.add(HierarchyParentModel.fromJson(v));
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

class HierarchyParentModel {
  int? id;
  String? name;
  String? slug;
  String? description;
  String? image;
  int? isActive;
  List<HierarchyChildModel>? children;

  HierarchyParentModel({
    this.id,
    this.name,
    this.slug,
    this.description,
    this.image,
    this.isActive,
    this.children,
  });

  HierarchyParentModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = json['name'];
    slug = json['slug'];
    description = json['description'];
    image = json['image'];
    isActive = _parseInt(json['is_active']);
    if (json['children'] != null) {
      children = <HierarchyChildModel>[];
      json['children'].forEach((v) {
        children!.add(HierarchyChildModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['description'] = description;
    data['image'] = image;
    data['is_active'] = isActive;
    if (children != null) {
      data['children'] = children!.map((v) => v.toJson()).toList();
    }
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

class HierarchyChildModel {
  int? id;
  int? parentId;
  String? name;
  String? slug;
  String? description;
  String? image;
  int? isActive;

  HierarchyChildModel({
    this.id,
    this.parentId,
    this.name,
    this.slug,
    this.description,
    this.image,
    this.isActive,
  });

  HierarchyChildModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    parentId = _parseInt(json['parent_id']);
    name = json['name'];
    slug = json['slug'];
    description = json['description'];
    image = json['image'];
    isActive = _parseInt(json['is_active']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['parent_id'] = parentId;
    data['name'] = name;
    data['slug'] = slug;
    data['description'] = description;
    data['image'] = image;
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
