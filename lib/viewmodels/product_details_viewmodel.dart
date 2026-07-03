import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/models/cart_item_model.dart';
import '../data/models/product_model.dart';
import '../data/models/wishlist_item_model.dart';
import '../core/cart/cart_coordinator.dart';
import '../core/network/network_error_utils.dart';
import '../models/list_review_model.dart' as review_model;
import '../models/product_list_model.dart';
import '../data/repositories/cart_repository.dart';
import '../data/repositories/wishlist_repository.dart';
import '../core/wishlist/wishlist_coordinator.dart';
import '../services/api_service.dart';
import 'base_viewmodel.dart';

class ProductDetailsViewModel extends BaseViewModel {
  final ProductModel product;
  final CartRepository _cartRepository;
  final WishlistRepository _wishlistRepository;
  final ApiService _apiService = ApiService();

  ProductDetailsViewModel({
    required this.product,
    required CartRepository cartRepository,
    required WishlistRepository wishlistRepository,
  }) : _cartRepository = cartRepository,
       _wishlistRepository = wishlistRepository;

  StreamSubscription<List<CartItemModel>>? _cartSub;
  StreamSubscription<List<WishlistItemModel>>? _wishlistSub;

  int _quantity = 1;
  int get quantity => _quantity;

  int _cartQuantity = 0;
  int get cartQuantity => _cartQuantity;
  bool get isInCart => _cartQuantity > 0;

  bool _isWishlisted = false;
  bool get isWishlisted => _isWishlisted;

  List<String> _imageUrls = const [];
  List<String> get imageUrls => _imageUrls;

  List<ProductModel> _similarProducts = const [];
  List<ProductModel> get similarProducts => _similarProducts;

  List<ProductModel> _recommendedProducts = const [];
  List<ProductModel> get recommendedProducts => _recommendedProducts;

  List<ProductModel> _categorySearchProducts = const [];
  List<ProductModel> get categorySearchProducts => _categorySearchProducts;

  String? _apiName;
  String? _apiDescription;
  String? _apiShortDescription;
  String? _apiBrand;
  String? _apiUnitLabel;
  bool? _apiCouponApplicable;
  int? _apiDiscountPercentage;
  bool? _apiInStock;
  int? _apiMaxOrderQuantity;
  int? _apiMinOrderQuantity;
  String? _apiEstimatedDeliveryTime;
  DateTime? _apiExpiryDate;
  DateTime? _apiManufacturingDate;
  String? _apiCountryOfOrigin;
  String? _apiDeliveryType;
  int? _apiDeliveryCharge;
  bool? _apiFreeDelivery;
  String? _apiSku;
  String? _apiWeight;
  String? _apiAttributes;
  String? _apiCategoryLabel;
  double? _apiPrice;
  double? _apiOriginalPrice;
  int? _apiStockLeft;
  double? _apiAverageRating;
  int? _apiReviewCount;
  List<review_model.Data> _apiReviews = const <review_model.Data>[];

  String get displayName =>
      (_apiName ?? '').trim().isNotEmpty ? _apiName!.trim() : product.name;

  String get displayCategoryLabel => (_apiCategoryLabel ?? '').trim().isNotEmpty
      ? _apiCategoryLabel!.trim()
      : product.category.displayName;

  double get displayPrice => _apiPrice ?? product.price;
  double? get displayOriginalPrice =>
      _apiOriginalPrice ?? product.originalPrice;
  int? get displayStockLeft => _apiStockLeft ?? product.stockLeft;
  String? get productDescription => _nonEmpty(_apiDescription);
  String? get productShortDescription => _nonEmpty(_apiShortDescription);
  String? get productBrand => _nonEmpty(_apiBrand);
  String? get productUnitLabel => _nonEmpty(_apiUnitLabel);
  bool? get productCouponApplicable => _apiCouponApplicable;
  int? get productDiscountPercentage => _apiDiscountPercentage;
  bool? get productInStock => _apiInStock;
  int? get productMaxOrderQuantity => _apiMaxOrderQuantity;
  int? get productMinOrderQuantity => _apiMinOrderQuantity;
  String? get productEstimatedDeliveryTime =>
      _nonEmpty(_apiEstimatedDeliveryTime);
  DateTime? get productExpiryDate => _apiExpiryDate;
  DateTime? get productManufacturingDate => _apiManufacturingDate;
  String? get productCountryOfOrigin => _nonEmpty(_apiCountryOfOrigin);
  String? get productDeliveryType => _nonEmpty(_apiDeliveryType);
  int? get productDeliveryCharge => _apiDeliveryCharge;
  bool? get productFreeDelivery => _apiFreeDelivery;
  double? get reviewAverageRating => _apiAverageRating;
  int get reviewCount => _apiReviewCount ?? _apiReviews.length;
  List<review_model.Data> get topReviews =>
      _apiReviews.take(3).toList(growable: false);
  bool get hasReviewData =>
      reviewAverageRating != null || reviewCount > 0 || _apiReviews.isNotEmpty;
  List<int> get reviewDistribution => List<int>.generate(
    5,
    (i) => _apiReviews.where((r) => (r.rating ?? 0) == 5 - i).length,
  );
  String? get displaySku => _nonEmpty(_apiSku);
  String? get displayWeight => _nonEmpty(_apiWeight);
  String? get displayAttributes => _nonEmpty(_apiAttributes);
  String get primaryImageUrl =>
      _imageUrls.isNotEmpty ? _imageUrls.first : product.imageUrl;
  bool get hasProductDetailsTableData =>
      displayCategoryLabel.trim().isNotEmpty ||
      displaySku != null ||
      displayWeight != null ||
      displayAttributes != null ||
      displayStockLeft != null ||
      productShortDescription != null ||
      productBrand != null ||
      productUnitLabel != null ||
      productCouponApplicable != null ||
      productDiscountPercentage != null ||
      productInStock != null ||
      productMaxOrderQuantity != null ||
      productMinOrderQuantity != null ||
      productEstimatedDeliveryTime != null ||
      productExpiryDate != null ||
      productManufacturingDate != null ||
      productCountryOfOrigin != null ||
      productDeliveryType != null ||
      productDeliveryCharge != null ||
      productFreeDelivery != null;

  String? get displayDiscountTag {
    if (displayOriginalPrice != null && displayOriginalPrice! > displayPrice) {
      final off =
          ((displayOriginalPrice! - displayPrice) / displayOriginalPrice! * 100)
              .round();
      if (off > 0) {
        return '$off% OFF';
      }
    }
    return product.discountTag;
  }

  Future<void> init() async {
    if (isLoading) return;

    setLoading(true);
    clearError();

    try {
      _imageUrls = product.imageUrl.trim().isNotEmpty
          ? <String>[product.imageUrl]
          : const <String>[];

      await Future.wait([_cartRepository.init(), _wishlistRepository.init()]);

      _syncCartSnapshot(await _cartRepository.getItems());
      _syncWishlistSnapshot(await _wishlistRepository.getItems());

      _cartSub?.cancel();
      _cartSub = _cartRepository.watchItems().listen(_syncCartSnapshot);

      _wishlistSub?.cancel();
      _wishlistSub = _wishlistRepository.watchItems().listen(
        _syncWishlistSnapshot,
      );

      _similarProducts = const <ProductModel>[];
      _recommendedProducts = const <ProductModel>[];
      _categorySearchProducts = const <ProductModel>[];

      await _hydrateFromApi();
    } catch (e) {
      if (isNetworkError(e)) {
        setNetworkError();
      } else {
        setError('Failed to load product.');
      }
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _hydrateFromApi() async {
    final productId = int.tryParse(product.id);
    if (productId == null) return;

    try {
      final detail = await _apiService.getProductDetails(productId);
      final detailData = detail.data;

      if (detailData != null) {
        debugPrint('--- [DEBUG] Viewmodel hydrating from API ---');
        debugPrint('Raw images from model: ${detailData.images}');
        
        final images = (detailData.images ?? const <String>[])
            .map(_apiService.resolveImageUrl)
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false);
            
        debugPrint('Resolved images: $images');
            
        if (images.isNotEmpty) {
          _imageUrls = images;
        }

        if ((detailData.name ?? '').trim().isNotEmpty) {
          _apiName = detailData.name;
        }
        if ((detailData.categoryName ?? '').trim().isNotEmpty) {
          _apiCategoryLabel = detailData.categoryName;
        }
        if ((detailData.description ?? '').trim().isNotEmpty) {
          _apiDescription = detailData.description;
        }
        if ((detailData.shortDescription ?? '').trim().isNotEmpty) {
          _apiShortDescription = detailData.shortDescription;
        }
        if ((detailData.brand ?? '').trim().isNotEmpty) {
          _apiBrand = detailData.brand;
        }
        if ((detailData.unitLabel ?? '').trim().isNotEmpty) {
          _apiUnitLabel = detailData.unitLabel;
        }
        _apiCouponApplicable = detailData.couponApplicable;
        _apiDiscountPercentage = detailData.discountPercentage;
        _apiInStock = detailData.isInStock;
        _apiMaxOrderQuantity = detailData.maxOrderQuantity;
        _apiMinOrderQuantity = detailData.minOrderQuantity;
        if ((detailData.estimatedDeliveryTime ?? '').trim().isNotEmpty) {
          _apiEstimatedDeliveryTime = detailData.estimatedDeliveryTime;
        }
        _apiExpiryDate = detailData.expiryDate;
        _apiManufacturingDate = detailData.manufacturingDate;
        if ((detailData.countryOfOrigin ?? '').trim().isNotEmpty) {
          _apiCountryOfOrigin = detailData.countryOfOrigin;
        }
        if ((detailData.deliveryType ?? '').trim().isNotEmpty) {
          _apiDeliveryType = detailData.deliveryType;
        }
        _apiDeliveryCharge = detailData.deliveryCharge;
        _apiFreeDelivery = detailData.freeDelivery;

        final base = double.tryParse(
          (detailData.price ?? '').toString().trim(),
        );
        final discount = double.tryParse(
          (detailData.discountPrice ?? '').toString().trim(),
        );

        if (base != null) {
          if (discount != null && discount > 0 && discount < base) {
            _apiPrice = discount;
            _apiOriginalPrice = base;
          } else {
            _apiPrice = base;
            _apiOriginalPrice = null;
          }
        }

        _apiStockLeft = detailData.stockQuantity ?? detailData.stock;
      }

      try {
        final reviewResponse = await _apiService.getReviewsList(
          productId: productId,
        );
        _apiAverageRating = reviewResponse.averageRating;
        _apiReviewCount = reviewResponse.reviewCount;

        final filtered = (reviewResponse.data ?? const <review_model.Data>[])
            .where(_shouldRenderReview)
            .toList(growable: true);

        filtered.sort((a, b) {
          final ratingCmp = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (ratingCmp != 0) return ratingCmp;
          return _safeReviewDate(b).compareTo(_safeReviewDate(a));
        });
        _apiReviews = filtered.toList(growable: false);
      } catch (_) {
        _apiAverageRating = null;
        _apiReviewCount = null;
        _apiReviews = const <review_model.Data>[];
      }

      final list = await _apiService.getProducts();
      final apiAll = (list.data ?? const <Data>[])
          .where(
            (item) => item.id != null && (item.name ?? '').trim().isNotEmpty,
          )
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            // Note: In details view we might not have all categories loaded,
            // but we can at least pass through the item's existing categoryName
            return _mapApiProduct(item, entry.key);
          })
          .toList(growable: false);

      final sameCategory = apiAll
          .where((p) {
            final cat = (p.categoryName ?? p.category.displayName).toLowerCase();
            final current = displayCategoryLabel.toLowerCase();
            return cat == current && p.id != product.id;
          })
          .toList(growable: false);

      if (sameCategory.isNotEmpty) {
        _similarProducts = sameCategory.take(6).toList(growable: false);
        _categorySearchProducts = sameCategory;
      }

      if (apiAll.isNotEmpty) {
        _recommendedProducts = apiAll
            .where((p) => p.id != product.id)
            .take(6)
            .toList(growable: false);
      }
    } catch (e) {
      if (isNetworkError(e)) rethrow;
      // Preserve already-loaded API/list item data if detail hydration fails.
    }
  }

  bool _shouldRenderReview(review_model.Data review) {
    final status = (review.status ?? '').trim().toLowerCase();
    if (status.isEmpty) return true;
    return status == 'approved' ||
        status == 'active' ||
        status == 'published' ||
        status == '1';
  }

  DateTime _safeReviewDate(review_model.Data review) {
    final parsed = DateTime.tryParse((review.createdAt ?? '').trim());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  ProductModel _mapApiProduct(Data item, int index) {
    final id = item.id?.toString() ?? 'detail-api-$index';
    final price = item.price?.toDouble() ?? 0.0;

    return ProductModel(
      id: id,
      category: _categoryFromApiName(item.categoryName),
      name: item.name!.trim(),
      imageUrl: _apiService.resolveImageUrl((item.images != null && item.images!.isNotEmpty) ? item.images!.first : null),
      price: price,
      originalPrice: null,
      discountTag: null,
      rating: null,
      reviewCount: null,
      reviews: const [],
      stockLeft: null,
      isFastDelivery: null,
      isBestSeller: null,
      categoryName: item.categoryName,
      categoryId: item.categoryId,
    );
  }

  ProductCategory _categoryFromApiName(String? categoryName) {
    final value = (categoryName ?? '').toLowerCase();
    if (value.contains('beauty')) return ProductCategory.beauty;
    if (value.contains('shoe') || value.contains('footwear')) {
      return ProductCategory.shoes;
    }
    if (value.contains('fresh') || value.contains('vegetable')) {
      return ProductCategory.fresh;
    }
    if (value.contains('snack')) return ProductCategory.snacks;
    if (value.contains('drink') || value.contains('beverage')) {
      return ProductCategory.drinks;
    }
    if (value.contains('dairy')) return ProductCategory.dairy;
    if (value.contains('paan') || value.contains('tobacco')) {
      return ProductCategory.tobacco;
    }
    return ProductCategory.grocery;
  }

  void _syncCartSnapshot(List<CartItemModel> items) {
    final match = items.cast<CartItemModel?>().firstWhere(
      (e) => e?.productId == product.id,
      orElse: () => null,
    );

    final nextCartQty = match?.quantity ?? 0;
    if (_cartQuantity != nextCartQty) {
      _cartQuantity = nextCartQty;
    }

    final targetQty = (_cartQuantity > 0 ? _cartQuantity : _quantity).clamp(
      1,
      999,
    );
    if (_quantity != targetQty) {
      _quantity = targetQty;
    }

    notifyListeners();
  }

  void _syncWishlistSnapshot(List<WishlistItemModel> items) {
    final next = items.any((e) => e.productId == product.id);
    if (_isWishlisted != next) {
      _isWishlisted = next;
      notifyListeners();
    }
  }

  void setQuantity(int value) {
    final next = value.clamp(1, 999);
    if (_quantity == next) return;
    _quantity = next;
    notifyListeners();
  }

  Future<void> incrementQuantity() async {
    setQuantity(_quantity + 1);
    if (isInCart) {
      await _cartRepository.setQuantity(product.id, _quantity);
    }
  }

  Future<void> decrementQuantity() async {
    if (_quantity <= 1) return;
    setQuantity(_quantity - 1);
    if (isInCart) {
      await _cartRepository.setQuantity(product.id, _quantity);
    }
  }

  Future<CartActionResult> addToCart() async {
    return CartCoordinator.instance.addItem(
      CartItemModel(
        productId: product.id,
        name: displayName,
        imageUrl: primaryImageUrl,
        unitPrice: displayPrice,
        quantity: _quantity,
      ),
    );
  }

  Future<void> addProductToCart(ProductModel p, {int quantity = 1}) async {
    await CartCoordinator.instance.addItem(
      CartItemModel(
        productId: p.id,
        name: p.name,
        imageUrl: p.imageUrl,
        unitPrice: p.price,
        quantity: quantity.clamp(1, 999),
      ),
    );
  }

  Future<WishlistActionResult> toggleWishlist() async {
    if (_isWishlisted) {
      return WishlistCoordinator.instance.removeItem(product.id);
    }

    return WishlistCoordinator.instance.addItem(
      WishlistItemModel(
        productId: product.id,
        name: displayName,
        imageUrl: primaryImageUrl,
        sku: null,
        unitPrice: displayPrice,
      ),
    );
  }

  String? _nonEmpty(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    _wishlistSub?.cancel();
    super.dispose();
  }
}
