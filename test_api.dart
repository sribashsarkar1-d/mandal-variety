import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/models/product_list_model.dart';
import 'lib/models/order_models.dart';

void main() async {
  print('Fetching products...');
  try {
    final res = await http.get(Uri.parse('https://api.mandal-variety.com/products/list.php'));
    final json = jsonDecode(res.body);
    final pl = ProductList.fromJson(json);
    print('Products parsed successfully: ${pl.data?.length}');
    
    // Now test cache encoding
    jsonEncode(pl.toJson());
    print('Products cached encoded successfully!');
  } catch (e, st) {
    print('Error in products: $e');
    print(st);
  }

  print('\nFetching orders (using generic user_id=1 as test)...');
  try {
    final res = await http.get(Uri.parse('https://api.mandal-variety.com/orders/list.php?user_id=1'));
    final json = jsonDecode(res.body);
    final ol = OrderList.fromJson(json);
    print('Orders parsed successfully: ${ol.data?.orders?.length}');
  } catch (e, st) {
    print('Error in orders: $e');
    print(st);
  }
}
