import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mandal_variety/common/cards/product_grid_card.dart';
import 'package:mandal_variety/core/cart/cart_coordinator.dart';
import 'package:mandal_variety/core/responsive/responsive_product_grid_config.dart';
import 'package:mandal_variety/core/theme/app_theme.dart';
import 'package:mandal_variety/core/wishlist/wishlist_coordinator.dart';
import 'package:mandal_variety/data/models/product_model.dart';
import 'package:mandal_variety/widgets/product_card_widget.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  bool _autoUncompress = true;
  @override
  bool get autoUncompress => _autoUncompress;
  @override
  set autoUncompress(bool value) => _autoUncompress = value;

  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _TestHttpClientRequest();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _TestHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final Uint8List _transparentImage = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _TestHttpHeaders();
  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  X509Certificate? get certificate => null;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => const <Cookie>[];
  @override
  int get contentLength => _transparentImage.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    HttpOverrides.global = _TestHttpOverrides();

    hiveDir = await Directory.systemTemp.createTemp('hive_responsive_test_');
    Hive.init(hiveDir.path);

    await CartCoordinator.instance.init();
    await WishlistCoordinator.instance.init();
  });

  tearDownAll(() async {
    HttpOverrides.global = null;
    await Hive.close();
    if (hiveDir.existsSync()) {
      await hiveDir.delete(recursive: true);
    }
  });

  final testProducts = [
    const ProductModel(
      id: '101',
      category: ProductCategory.grocery,
      categoryName: 'Dairy & Eggs',
      name: 'Organic Milk 1L',
      imageUrl: 'https://example.com/milk.png',
      price: 65.0,
      originalPrice: 75.0,
      discountTag: '13% OFF',
      rating: 4.8,
      reviewCount: 42,
    ),
    const ProductModel(
      id: '102',
      category: ProductCategory.fresh,
      categoryName: 'Fresh Fruits',
      name: 'Premium Extra Sweet Crisp Organic Gala Apples Imported Pack of 6',
      imageUrl: 'https://example.com/apples.png',
      price: 180.0,
      originalPrice: 220.0,
      discountTag: 'Save 18%',
      rating: 4.5,
      reviewCount: 19,
    ),
    const ProductModel(
      id: '103',
      category: ProductCategory.snacks,
      categoryName: 'Snacks & Munchies',
      name: 'Salted Almonds',
      imageUrl: 'https://example.com/almonds.png',
      price: 249.0,
      rating: 4.9,
      reviewCount: 88,
    ),
    const ProductModel(
      id: '104',
      category: ProductCategory.beauty,
      categoryName: 'Skin Care',
      name: 'Gentle Hydrating Daily Face Wash with Aloe Vera & Green Tea Extract',
      imageUrl: 'https://example.com/facewash.png',
      price: 299.0,
      originalPrice: 350.0,
      discountTag: 'Best Seller',
      rating: 4.7,
      reviewCount: 120,
    ),
  ];

  // List of logical screen widths explicitly requested in Master Prompt Section 10
  final screenWidthsToTest = <double>[
    320.0, // Small mobile (iPhone SE 1st gen, small Android)
    360.0, // Standard compact Android (Samsung Galaxy A series)
    375.0, // iPhone SE 2/3, iPhone 11 Pro, iPhone X
    393.0, // iPhone 14/15/16, Google Pixel
    412.0, // Google Pixel Pro, Samsung Galaxy S21/S22/S23+
    440.0, // Large mobile (Galaxy Ultra, Pro Max)
    500.0, // Foldable / small tablet
  ];

  for (final width in screenWidthsToTest) {
    testWidgets('Responsive Product Grid renders without overflow at ${width.toInt()}px width',
        (WidgetTester tester) async {
      final height = 800.0;
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProductGridSliver(
                  products: testProducts,
                  onProductTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull,
          reason: 'Expected no layout overflows at width: $width');

      // Verify that ProductCardWidget is built for items
      expect(find.byType(ProductCardWidget), findsWidgets);

      // Verify product titles exist
      expect(find.text('Organic Milk 1L'), findsOneWidget);

      // Verify prices exist
      expect(find.text('₹65.00'), findsOneWidget);

      // Verify "Add to Cart" buttons exist
      expect(find.text('Add to Cart'), findsWidgets);
    });

    testWidgets('Single ProductCardWidget adapts to card width for ${width.toInt()}px screen',
        (WidgetTester tester) async {
      final cardWidth = ResponsiveProductGridConfig.calculateCardWidth(containerWidth: width);
      final cardHeight = ResponsiveProductGridConfig.calculateCardHeight(cardWidth);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: ProductCardWidget(
                  productId: 999,
                  name: 'Responsive Test Product with Long Name That Takes Two Full Lines',
                  priceText: 'Rs 199.00',
                  oldPriceText: 'Rs 249.00',
                  categoryName: 'Groceries',
                  imageUrl: 'https://example.com/test.png',
                  discountBadgeText: '20% OFF',
                  rating: 4.8,
                  reviewCount: 30,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Rs 199.00'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);

      // Verify 1:1 AspectRatio is used for image
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, 1.0);
    });
  }
}
