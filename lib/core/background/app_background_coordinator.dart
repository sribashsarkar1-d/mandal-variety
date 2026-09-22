import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';

class AppBackgroundCoordinator {
  AppBackgroundCoordinator._();

  static final AppBackgroundCoordinator instance = AppBackgroundCoordinator._();

  final ApiService _apiService = ApiService();

  final ValueNotifier<String?> backgroundUrl = ValueNotifier<String?>(null);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final response = await _apiService.getAppBackground();
      if (response.success == true && response.data?.imageFullUrl != null) {
        backgroundUrl.value = response.data!.imageFullUrl;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppBackgroundCoordinator] Failed to fetch background: $e');
      }
    }
  }
}
