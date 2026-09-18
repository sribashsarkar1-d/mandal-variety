import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ApiCacheService {
  ApiCacheService._();
  static final ApiCacheService instance = ApiCacheService._();

  static const String _boxName = 'api_cache_box';
  Box<String>? _box;

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
  }

  Future<void> cacheJson(String key, Map<String, dynamic> json) async {
    await init();
    final jsonString = jsonEncode(json);
    await _box!.put(key, jsonString);
  }

  Future<Map<String, dynamic>?> getCachedJson(String key) async {
    await init();
    final jsonString = _box!.get(key);
    if (jsonString != null) {
      try {
        final decoded = await compute(_decodeJson, jsonString);
        return decoded;
      } catch (e) {
        debugPrint('Cache decode error for key $key: $e');
        return null;
      }
    }
    return null;
  }
  Future<void> clearCache() async {
    await init();
    await _box!.clear();
  }
}

Map<String, dynamic> _decodeJson(String data) {
  return jsonDecode(data) as Map<String, dynamic>;
}
