class ListPolicies {
  bool? success;
  List<PolicyListItem>? data;

  ListPolicies({this.success, this.data});

  ListPolicies.fromJson(Map<String, dynamic> json) {
    success = json['success'] == true;
    if (json['data'] is List) {
      data = <PolicyListItem>[];
      for (final item in (json['data'] as List)) {
        if (item is Map<String, dynamic>) {
          data!.add(PolicyListItem.fromJson(item));
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['success'] = success;
    if (data != null) {
      map['data'] = data!.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class PolicyListItem {
  int? id;
  String? title;
  String? slug;
  String? type;
  String? shortDescription;
  String? content;
  String? status;
  String? visibility;
  int? isFeatured;
  int? displayOrder;

  PolicyListItem({
    this.id,
    this.title,
    this.slug,
    this.type,
    this.shortDescription,
    this.content,
    this.status,
    this.visibility,
    this.isFeatured,
    this.displayOrder,
  });

  PolicyListItem.fromJson(Map<String, dynamic> json) {
    id = _asInt(json['id']);
    title = json['title']?.toString();
    slug = json['slug']?.toString();
    type = json['type']?.toString();
    shortDescription = json['short_description']?.toString();
    content = json['content']?.toString();
    status = json['status']?.toString();
    visibility = json['visibility']?.toString();
    isFeatured = _asInt(json['is_featured']);
    displayOrder = _asInt(json['display_order']);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    map['slug'] = slug;
    map['type'] = type;
    map['short_description'] = shortDescription;
    map['content'] = content;
    map['status'] = status;
    map['visibility'] = visibility;
    map['is_featured'] = isFeatured;
    map['display_order'] = displayOrder;
    return map;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
