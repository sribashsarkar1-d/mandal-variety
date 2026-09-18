import '../core/network/network_error_utils.dart';
import '../models/order_models.dart';
import '../services/api_service.dart';
import 'base_viewmodel.dart';

class OrdersViewModel extends BaseViewModel {
  final ApiService _apiService = ApiService();
  
  List<OrderListItem> _orders = [];
  List<OrderListItem> get orders => _orders;

  String? _selectedFilter;
  String? get selectedFilter => _selectedFilter;

  OrdersViewModel();

  Future<void> init() async {
    await fetchOrders();
  }

  void setFilter(String? filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  List<OrderListItem> get filteredOrders {
    if (_selectedFilter == null) {
      return _orders;
    }
    return _orders.where((order) {
      final s = order.status?.toLowerCase() ?? 'pending';
      final filterLower = _selectedFilter!.toLowerCase();
      if (s == filterLower) return true;
      if ((s == '' || s == 'pending') && filterLower == 'pending') return true;
      if ((s == 'completed' || s == 'success') && filterLower == 'delivered') return true;
      if ((s == 'shipped' || s == 'transit') && filterLower == 'in transit') return true;
      if ((s == 'prepare' || s == 'preparing') && filterLower == 'processing') return true;
      return false;
    }).toList();
  }

  Future<void> fetchOrders() async {
    setLoading(true);
    clearError();
    try {
      final response = await _apiService.getOrdersList();
      if (response.success == true && response.data != null && response.data!.orders != null) {
        // Exclude astronomical stress-test mock orders (e.g. > 100,000) to keep presentation pricing real
        _orders = response.data!.orders!
            .where((order) => (order.totalAmount ?? 0.0) < 100000.0)
            .toList();
        notifyListeners();
      } else {
        setError(response.message ?? 'Failed to load orders.');
      }
    } catch (e) {
      if (isNetworkError(e)) {
        setNetworkError();
      } else {
        setError('Failed to fetch orders history. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  }

  Future<bool> executeCancelOrder(int orderId) async {
    setLoading(true);
    clearError();
    try {
      final response = await _apiService.cancelOrder(orderId: orderId);
      if (response.success == true) {
        await fetchOrders(); // refresh
        return true;
      } else {
        setError(response.message ?? 'Failed to cancel order.');
        return false;
      }
    } catch (e) {
      if (isNetworkError(e)) {
        setNetworkError();
      } else {
        setError('Failed to cancel the order. Please try again.');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }
}
