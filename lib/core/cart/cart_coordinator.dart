import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_coordinator.dart';
import '../../core/utils/platform_helper.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/hive_cart_repository.dart';
import '../../models/cart_add_model.dart';
import '../../models/cart_detail_model.dart';
import '../../services/api_service.dart';
import '../../views/cart/cart_view.dart';

class CartActionResult {
  final bool success;
  final String message;

  const CartActionResult({required this.success, required this.message});
}

/// Global coordinator for Cart state.
///
/// Keeps app bars in sync (badge count) and centralizes navigation to Cart.
/// View/UI layers can later swap the repository (API) without changing widgets.
class CartCoordinator {
  CartCoordinator._();

  static final CartCoordinator instance = CartCoordinator._();

  final CartRepository _repository = HiveCartRepository();
  final ApiService _apiService = ApiService();
  StreamSubscription<List<CartItemModel>>? _sub;

  final ValueNotifier<int> itemCount = ValueNotifier<int>(0);
  final ValueNotifier<double> subtotal = ValueNotifier<double>(0.0);

  bool _initialized = false;

  bool get _hasSession =>
      AuthCoordinator.instance.hasActiveToken() ||
      AuthCoordinator.instance.currentUserId != null;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _repository.init();

    _sub?.cancel();
    _sub = _repository.watchItems().listen((items) {
      final count = items.fold<int>(0, (sum, e) => sum + e.quantity);
      itemCount.value = count;

      final nextSubtotal = items.fold<double>(
        0.0,
        (sum, e) => sum + (e.unitPrice * e.quantity),
      );
      subtotal.value = nextSubtotal;
    });

    await _attemptSyncFromServer();
  }

  Future<CartActionResult> addItem(CartItemModel item) async {
    await init();

    final productId = int.tryParse(item.productId.trim());
    final safeQuantity = item.quantity.clamp(1, 999);
    if (!_hasSession) {
      return const CartActionResult(
        success: false,
        message: 'Please login first',
      );
    }

    if (productId != null) {
      Cartadd? response;
      try {
        response = await _apiService.addToCart(
          productId: productId,
          quantity: safeQuantity,
          productName: item.name,
        );
      } on ApiServiceException catch (e) {
        return CartActionResult(
          success: false,
          message:
              'Add to cart failed for product_id=$productId, quantity=$safeQuantity. Server says: ${e.message}',
        );
      } catch (_) {
        return CartActionResult(
          success: false,
          message:
              'Add to cart failed for product_id=$productId, quantity=$safeQuantity. Please try again.',
        );
      }

      if (response.success == true) {
        // Prefer server-confirmed identifiers/quantity but keep local metadata.
        await _applyLocalCartAdd(item, response);

        return CartActionResult(
          success: true,
          message: (response.message ?? '').trim().isNotEmpty
              ? response.message!.trim()
              : 'Added to cart',
        );
      }

      final serverMessage = (response.message ?? '').trim().isNotEmpty
          ? response.message!.trim()
          : 'Unknown server error';
      return CartActionResult(
        success: false,
        message:
            'Add to cart failed for product_id=$productId, quantity=$safeQuantity. Server says: $serverMessage',
      );
    } else {
      // Mock item fallback (non-numeric product ID)
      await _repository.upsertItem(item);
      return const CartActionResult(success: true, message: 'Added to cart');
    }
  }

  Future<void> setQuantity(String productId, int quantity) async {
    await init();
    final numericProductId = int.tryParse(productId.trim());
    final safeQuantity = quantity.clamp(1, 999);
    if (_hasSession) {
      final existingItems = await _repository.getItems();
      final existing = existingItems.firstWhere(
        (e) => e.productId == productId,
        orElse: () => CartItemModel(
          productId: productId,
          name: 'Product $productId',
          unitPrice: 0.0,
          quantity: 0,
        ),
      );

      final delta = safeQuantity - (existing.quantity == 0 ? 0 : existing.quantity);
      if (delta == 0 && existing.quantity != 0) return;

      // Optimistic update
      await _repository.setQuantity(productId, safeQuantity);

      if (numericProductId != null) {
        bool remoteSuccess = false;
        try {
          await _apiService.updateCart(
            productId: numericProductId,
            quantity: safeQuantity,
          );
          remoteSuccess = true;
        } catch (_) {
          try {
            await _apiService.addToCart(
              productId: numericProductId,
              quantity: delta,
            );
            remoteSuccess = true;
          } catch (_) {}
        }

        if (remoteSuccess) {
          await _attemptSyncFromServer();
        }
      }
    }
  }

  Future<void> removeItem(String productId) async {
    await init();
    final numericProductId = int.tryParse(productId.trim());
    if (_hasSession) {
      // Optimistic update
      await _repository.removeItem(productId);

      if (numericProductId != null) {
        bool remoteSuccess = false;
        try {
          await _apiService.removeFromCart(productId: numericProductId);
          remoteSuccess = true;
        } catch (_) {}

        if (remoteSuccess) {
          await _attemptSyncFromServer();
        }
      }
    }
  }

  Future<void> clear() async {
    await init();
    if (_hasSession) {
      bool remoteSuccess = false;
      try {
        await _apiService.clearCart();
        remoteSuccess = true;
      } catch (_) {}

      if (remoteSuccess) {
        await _repository.clear();
        await _attemptSyncFromServer();
      }
    }
  }

  Future<void> syncFromServer() async {
    await init();

    await _attemptSyncFromServer();
  }

  Future<void> _attemptSyncFromServer() async {
    try {
      await _syncFromServerIfPossible();
    } catch (e, stack) {
      debugPrint('[CartCoordinator] Sync failed: $e\n$stack');
      // Keep local repository state as source of truth temporarily.
    }
  }

  Future<void> _applyLocalCartAdd(CartItemModel item, Cartadd response) async {
    final serverProductId = response.data?.productId?.toString();
    final serverQuantity = response.data?.quantity;

    final resolvedProductId = (serverProductId ?? item.productId).trim().isEmpty
        ? item.productId
        : (serverProductId ?? item.productId).trim();
    final resolvedQuantity = (serverQuantity ?? item.quantity).clamp(1, 999);

    await _repository.upsertItem(
      CartItemModel(
        productId: resolvedProductId,
        name: item.name,
        imageUrl: item.imageUrl,
        unitPrice: item.unitPrice,
        quantity: resolvedQuantity,
      ),
    );
  }

  Future<void> _syncFromServerIfPossible() async {
    if (!_initialized) {
      return;
    }

    if (!AuthCoordinator.instance.isLoggedIn || !_hasSession) {
      await _repository.clear();
      return;
    }

    final response = await _apiService.getCartDetail();
    if (response == null) {
      debugPrint(
        '[CartCoordinator] Sync skipped: cart detail unavailable; keeping local state.',
      );
      return;
    }

    if (response.success != true || response.data == null) {
      debugPrint(
        '[CartCoordinator] Sync skipped: invalid cart payload; keeping local state.',
      );
      return;
    }

    final items = response.data?.items ?? <CartDetailItem>[];

    await _repository.clear();
    for (final item in items) {
      final productId = item.productId?.toString();
      final name = (item.name ?? '').trim();
      final price = double.tryParse((item.price ?? '').toString()) ?? 0.0;
      final quantity = item.quantity ?? 1;

      if (productId == null || productId.isEmpty) {
        continue;
      }

      final displayName = name.isEmpty ? 'Product $productId' : name;

      await _repository.upsertItem(
        CartItemModel(
          productId: productId,
          name: displayName,
          imageUrl: _apiService.resolveImageUrl(item.images),
          unitPrice: price,
          quantity: quantity,
        ),
      );
    }
  }

  Future<List<CartItemModel>> getItems() async {
    await init();
    return _repository.getItems();
  }

  Stream<List<CartItemModel>> watchItems() async* {
    await init();
    yield* _repository.watchItems();
  }

  void openCart(BuildContext context, {int currentBottomBarIndex = 0}) {
    final route = PlatformHelper.isIOS
        ? CupertinoPageRoute<void>(
            builder: (_) =>
                CartView(currentBottomBarIndex: currentBottomBarIndex),
          )
        : MaterialPageRoute<void>(
            builder: (_) =>
                CartView(currentBottomBarIndex: currentBottomBarIndex),
          );

    Navigator.of(context).push(route);
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _sub?.cancel();
    itemCount.dispose();
    subtotal.dispose();
  }
}
