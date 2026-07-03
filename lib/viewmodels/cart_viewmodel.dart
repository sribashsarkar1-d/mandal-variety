import 'dart:async';

import '../core/network/network_error_utils.dart';
import '../core/cart/cart_coordinator.dart';
import '../core/cart/cart_pricing.dart';
import '../data/models/cart_item_model.dart';
import 'base_viewmodel.dart';

class CartViewModel extends BaseViewModel {
  StreamSubscription<List<CartItemModel>>? _sub;

  List<CartItemModel> _items = const [];
  List<CartItemModel> get items => _items;

  CartViewModel();

  Future<void> init() async {
    setLoading(true);
    clearError();

    try {
      await CartCoordinator.instance.init();
      _sub?.cancel();
      _sub = CartCoordinator.instance.watchItems().listen((items) {
        _items = items;
        notifyListeners();
      });
    } catch (e) {
      if (isNetworkError(e)) {
        setNetworkError();
      } else {
        setError('Failed to load cart.');
      }
    } finally {
      setLoading(false);
    }
  }

  bool get isEmpty => _items.isEmpty;

  int get totalQuantity => _items.fold<int>(0, (sum, e) => sum + e.quantity);

  double get subtotal =>
      _items.fold<double>(0.0, (sum, e) => sum + (e.unitPrice * e.quantity));

  /// Pricing rules:
  /// - Subtotal >= 99: delivery is free + 10 handling charge
  /// - 49 <= Subtotal < 99: +20 small-order surcharge
  /// - Subtotal >= 19: +30 delivery charge (unless Subtotal >= 99)
  double get deliveryCharge {
    if (isEmpty) return 0.0;
    return CartPricing.deliveryChargeAmount;
  }

  double get handlingCharge => 0.0;

  double get smallOrderSurcharge => 0.0;

  double get totalFees => deliveryCharge + handlingCharge + smallOrderSurcharge;

  double get totalAmount => subtotal + totalFees;

  CartItemModel? _find(String productId) {
    for (final item in _items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  Future<void> increment(String productId) async {
    final item = _find(productId);
    if (item == null) return;
    await CartCoordinator.instance.setQuantity(productId, item.quantity + 1);
  }

  Future<void> decrement(String productId) async {
    final item = _find(productId);
    if (item == null) return;
    if (item.quantity <= 1) return;
    await CartCoordinator.instance.setQuantity(productId, item.quantity - 1);
  }

  Future<void> remove(String productId) async {
    await CartCoordinator.instance.removeItem(productId);
  }

  Future<void> add(CartItemModel item) async {
    await CartCoordinator.instance.addItem(item);
  }

  Future<void> clear() async {
    await CartCoordinator.instance.clear();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
