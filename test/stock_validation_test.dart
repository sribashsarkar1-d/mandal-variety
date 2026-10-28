import 'package:mandal_variety/data/models/cart_item_model.dart';
import 'package:mandal_variety/models/cart_detail_model.dart';
import 'package:mandal_variety/models/order_models.dart';

void main() {
  print('=== Running Stock Validation Tests ===');

  // Test 1: Out of stock item
  final outOfStockItem = CartItemModel(
    productId: 'prod_1',
    name: 'Medisalic Ointment',
    unitPrice: 120.0,
    quantity: 1,
    availableStock: 0,
    isInStock: false,
  );
  assert(outOfStockItem.isOutOfStock == true, 'Expected isOutOfStock to be true');
  assert(outOfStockItem.hasInsufficientStock == false, 'Expected hasInsufficientStock to be false when completely out of stock');
  assert(outOfStockItem.isAvailable == false, 'Expected isAvailable to be false');
  print('Test 1 Passed: Out of stock item correctly identified');

  // Test 2: In stock item (qty <= availableStock)
  final inStockItem = CartItemModel(
    productId: 'prod_2',
    name: 'Paracetamol',
    unitPrice: 20.0,
    quantity: 2,
    availableStock: 5,
    isInStock: true,
  );
  assert(inStockItem.isOutOfStock == false, 'Expected isOutOfStock to be false');
  assert(inStockItem.hasInsufficientStock == false, 'Expected hasInsufficientStock to be false');
  assert(inStockItem.isAvailable == true, 'Expected isAvailable to be true');
  print('Test 2 Passed: In stock item correctly identified');

  // Test 3: Insufficient stock (stock 2, qty 5)
  final insufficientStockItem = CartItemModel(
    productId: 'prod_3',
    name: 'Hand Sanitizer',
    unitPrice: 50.0,
    quantity: 5,
    availableStock: 2,
    isInStock: true,
  );
  assert(insufficientStockItem.isOutOfStock == false, 'Expected isOutOfStock to be false');
  assert(insufficientStockItem.hasInsufficientStock == true, 'Expected hasInsufficientStock to be true');
  assert(insufficientStockItem.isAvailable == false, 'Expected isAvailable to be false');
  print('Test 3 Passed: Insufficient stock correctly identified');

  // Test 4: CartDetailModel JSON deserialization
  final cartJson = {
    'cart_id': 101,
    'user_id': 11,
    'status': 'active',
    'items': [
      {
        'id': 1,
        'cart_id': 101,
        'product_id': 55,
        'name': 'Medisalic Ointment',
        'price': 150.0,
        'quantity': 1,
        'stock_quantity': 0,
        'available_stock': 0,
        'isInStock': false,
        'is_in_stock': false,
        'has_insufficient_stock': true,
        'is_available': false,
      },
      {
        'id': 2,
        'cart_id': 101,
        'product_id': 56,
        'name': 'Moisturizer',
        'price': 250.0,
        'quantity': 3,
        'stock_quantity': 10,
        'available_stock': 10,
        'isInStock': true,
        'is_in_stock': true,
        'has_insufficient_stock': false,
        'is_available': true,
      }
    ],
    'total_amount': 900.0,
    'has_stock_issues': true,
  };

  final cartDetail = Cartdetail.fromJson(cartJson);
  final items = cartDetail.data?.items;
  assert(items?.length == 2, 'Expected 2 items in cart');
  assert(items![0].isOutOfStock == true, 'Expected item 0 out of stock');
  assert(items![0].isAvailable == false, 'Expected item 0 not available');
  assert(items![1].isOutOfStock == false, 'Expected item 1 in stock');
  assert(items![1].isAvailable == true, 'Expected item 1 available');
  print('Test 4 Passed: Cartdetail parsed stock fields properly');

  // Test 5: OrderCreate JSON error deserialization
  final errorJson = {
    'success': false,
    'message': 'Some products are out of stock. Please update your cart.',
    'unavailable_products': [
      {
        'product_id': 123,
        'product_name': 'Medisalic Ointment',
        'available_stock': 0,
      }
    ]
  };

  final orderRes = OrderCreate.fromJson(errorJson);
  assert(orderRes.success == false, 'Expected success == false');
  assert(orderRes.unavailableProducts?.length == 1, 'Expected 1 unavailable product');
  assert(orderRes.unavailableProducts![0].productId == 123, 'Expected productId == 123');
  assert(orderRes.unavailableProducts![0].productName == 'Medisalic Ointment', 'Expected name match');
  assert(orderRes.unavailableProducts![0].availableStock == 0, 'Expected stock == 0');
  print('Test 5 Passed: OrderCreate parsed unavailable_products properly');

  print('=== ALL 5 STOCK VALIDATION TESTS PASSED SUCCESSFULLY! ===');
}
