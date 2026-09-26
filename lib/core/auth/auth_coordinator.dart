import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';

// ============================================================================
// AUTH COORDINATOR  — Singleton
// Manages persistent authentication state via a Hive box.
// Follows the same Coordinator pattern used by CartCoordinator,
// WishlistCoordinator, etc.
// ============================================================================

class AuthCoordinator {
  AuthCoordinator._();

  static final AuthCoordinator instance = AuthCoordinator._();

  static const _boxName = 'auth';
  static const _keyLoggedIn = 'isLoggedIn';
  static const _keyOnboarding = 'onboardingCompleted';
  static const _keyUserId = 'userId';
  static const _keyUserToken = 'userToken';
  static const _keyUserName = 'userName';
  static const _keyUserEmail = 'userEmail';

  Box? _box;
  bool _initialized = false;

  /// Call once from main() before runApp.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _box = await Hive.openBox(_boxName);

    final hasToken = (currentUserToken ?? '').trim().isNotEmpty;
    final hasUserId = currentUserId != null;
    if ((hasToken || hasUserId) && !isLoggedIn) {
      await setLoggedIn(true);
    }
  }

  /// Whether a user session is currently active.
  bool get isLoggedIn => _box?.get(_keyLoggedIn, defaultValue: false) ?? false;

  /// Whether the user has already seen the onboarding flow.
  bool get onboardingCompleted =>
      _box?.get(_keyOnboarding, defaultValue: false) ?? false;

  int? get currentUserId {
    final raw = _box?.get(_keyUserId);
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  String? get currentUserToken => _box?.get(_keyUserToken)?.toString();
  Future<void> saveToken(String token) async {
    await _box?.put(_keyUserToken, token);
    await _box?.put(_keyLoggedIn, true);
  }

  String? getToken() => currentUserToken;

  Future<void> clearToken() async {
    await _box?.delete(_keyUserToken);
  }

  bool hasActiveToken() => (currentUserToken ?? '').trim().isNotEmpty;

  String? get currentUserName => _box?.get(_keyUserName)?.toString();
  String? get currentUserEmail => _box?.get(_keyUserEmail)?.toString();

  Map<String, dynamic> get currentUserSnapshot => <String, dynamic>{
    'userId': currentUserId,
    'name': currentUserName,
    'email': currentUserEmail,
    'token': currentUserToken,
  };

  /// Persist login state (true on successful OTP verification).
  Future<void> setLoggedIn(bool value) async {
    await _box?.put(_keyLoggedIn, value);
  }

  Future<void> setUserSession({
    required int? userId,
    String? token,
    String? name,
    String? email,
  }) async {
    final previousUserId = currentUserId;

    if (userId != null && previousUserId != null && previousUserId != userId) {
      final cartBox = await Hive.openBox('cart_box');
      await cartBox.put('items', '[]');

      final wishlistBox = await Hive.openBox('wishlist_box');
      await wishlistBox.put('items', '[]');
    }

    if (userId != null) {
      await _box?.put(_keyUserId, userId);
    }
    if (token != null) {
      await _box?.put(_keyUserToken, token);
    }
    if (name != null) {
      await _box?.put(_keyUserName, name);
    }
    if (email != null) {
      await _box?.put(_keyUserEmail, email);
    }

    // Refresh FCM Token for the newly logged-in user
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService().updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('Failed to update FCM token on login: $e');
    }
  }

  /// Mark onboarding as seen so it is skipped on subsequent launches.
  Future<void> setOnboardingCompleted() async {
    await _box?.put(_keyOnboarding, true);
  }

  /// Clear session and reset onboarding so the full flow replays after logout.
  Future<void> logout() async {
    await _box?.put(_keyLoggedIn, false);
    await _box?.put(_keyOnboarding, false);
    await _box?.delete(_keyUserId);
    await _box?.delete(_keyUserToken);
    await _box?.delete(_keyUserName);
    await _box?.delete(_keyUserEmail);

    // Clear user-scoped caches so next session starts cleanly.
    final cartBox = await Hive.openBox('cart_box');
    await cartBox.put('items', '[]');

    final wishlistBox = await Hive.openBox('wishlist_box');
    await wishlistBox.put('items', '[]');
  }
}
