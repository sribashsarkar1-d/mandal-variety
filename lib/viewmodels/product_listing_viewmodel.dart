import 'package:flutter/foundation.dart';
import '../data/models/product_model.dart';
import '../core/network/network_error_utils.dart';
import '../models/product_list_model.dart';
import '../models/categories_model.dart';
import '../services/api_service.dart';
import 'base_viewmodel.dart';

enum ListingType {
  all,
  parentCategory,
  childCategory,
  search,
  voiceSearch,
  related
}

enum ProductSort {
  popular,
  priceLowToHigh,
  priceHighToLow,
  ratingHighToLow,
  nameAZ,
}

enum ProductQuickFilter {
  all,
  under99,
  topRated,
  discounted,
}

extension ProductQuickFilterX on ProductQuickFilter {
  String get label {
    switch (this) {
      case ProductQuickFilter.all:
        return 'All'; 
      case ProductQuickFilter.under99:
        return 'Under ₹99';
      case ProductQuickFilter.topRated:
        return 'Top Rated'; 
      case ProductQuickFilter.discounted:
        return 'Discounted';
    }
  }
}

extension ProductSortX on ProductSort {
  String get label {
    switch (this) {
      case ProductSort.popular:
        return 'Popular';
      case ProductSort.priceLowToHigh:
        return 'Price: Low to High';
      case ProductSort.priceHighToLow:
        return 'Price: High to Low';
      case ProductSort.ratingHighToLow:
        return 'Rating';
      case ProductSort.nameAZ:
        return 'Name: A–Z';
    }
  }

  ProductSort get next {
    final values = ProductSort.values;
    return values[(index + 1) % values.length];
  }
}

class ProductListingViewModel extends BaseViewModel {
  ListingType type;
  int? parentCategoryId;
  int? childCategoryId;
  String _searchQuery;

  final ApiService _apiService = ApiService();

  ProductListingViewModel({
    this.type = ListingType.all,
    this.parentCategoryId,
    this.childCategoryId,
    String searchQuery = '',
  }) : _searchQuery = searchQuery;

  List<ProductModel> _products = const <ProductModel>[];
  List<ProductModel> get products => _products;

  String get searchQuery => _searchQuery;

  ProductSort _sort = ProductSort.popular;
  ProductSort get sort => _sort;

  ProductQuickFilter _quickFilter = ProductQuickFilter.all;
  ProductQuickFilter get quickFilter => _quickFilter;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  List<ProductModel> get filteredProducts {
    List<ProductModel> base = [..._products];

    // Local text filtering only if not an API search mode
    if (type != ListingType.search && type != ListingType.voiceSearch) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        base = base.where((p) => p.name.toLowerCase().contains(q)).toList();
      }
    }

    // Local category filtering
    if (type == ListingType.parentCategory && parentCategoryId != null) {
      base = base.where((p) => 
        p.parentCategoryId == parentCategoryId || p.categoryId == parentCategoryId
      ).toList();
    } else if (type == ListingType.childCategory && childCategoryId != null) {
      base = base.where((p) => 
        p.categoryId == childCategoryId || p.subcategoryId == childCategoryId
      ).toList();
    }

    final List<ProductModel> filtered = switch (_quickFilter) {
      ProductQuickFilter.all => base,
      ProductQuickFilter.under99 => base.where((p) => p.price < 99).toList(),
      ProductQuickFilter.topRated =>
        base.where((p) => (p.rating ?? 0.0) >= 4.5).toList(),
      ProductQuickFilter.discounted =>
        base.where((p) => p.hasDiscount).toList(),
    };

    switch (_sort) {
      case ProductSort.popular:
        return filtered;
      case ProductSort.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        return filtered;
      case ProductSort.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        return filtered;
      case ProductSort.ratingHighToLow:
        filtered.sort((a, b) {
          final ar = a.rating ?? 0.0;
          final br = b.rating ?? 0.0;
          final primary = br.compareTo(ar);
          if (primary != 0) return primary;
          return b.price.compareTo(a.price);
        });
        return filtered;
      case ProductSort.nameAZ:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return filtered;
    }
  }

  Future<void> load() async {
    setLoading(true);
    clearError();
    try {
      ProductList response;
      switch (type) {
        case ListingType.search:
          if (_searchQuery.trim().isEmpty) {
            response = ProductList(success: true, data: const <Data>[]);
          } else {
            response = await _apiService.searchProducts(query: _searchQuery);
          }
          break;
        case ListingType.voiceSearch:
          if (_searchQuery.trim().isEmpty) {
            response = ProductList(success: true, data: const <Data>[]);
          } else {
            response = await _apiService.voiceSearch(query: _searchQuery);
          }
          break;
        case ListingType.parentCategory:
          response = await _apiService.getProducts();
          break;
        case ListingType.childCategory:
          response = await _apiService.getProducts();
          break;
        case ListingType.all:
          response = await _apiService.getProducts();
          break;
        case ListingType.related:
          // In related, we might reuse childCategoryId as the product ID, or similar.
          // Since it's not strictly specified, let's keep it robust.
          if (childCategoryId != null) {
            response = await _apiService.getRelatedProducts(productId: childCategoryId!);
          } else {
            response = ProductList(success: true, data: const <Data>[]);
          }
          break;
      }

      final mapped = (response.data ?? const <Data>[])
          .asMap()
          .entries
          .map((entry) {
             return _mapApiProduct(entry.value, entry.key);
          })
          .toList(growable: false);

      _products = mapped;
      _hasMore = false;
    } catch (e) {
      if (isNetworkError(e)) {
        setNetworkError();
      } else {
        setError('Failed to load products.');
      }
    } finally {
      setLoading(false);
    }
  }

  ProductModel _mapApiProduct(Data item, int index) {
    final id = item.id?.toString() ?? 'listing-api-$index';
    final basePrice = item.price?.toDouble() ?? 0.0;
    final discountPrice = item.discountPrice?.toDouble();

    double finalPrice = basePrice;
    double? originalPrice;
    if (discountPrice != null && discountPrice > 0 && discountPrice < basePrice) {
      finalPrice = discountPrice;
      originalPrice = basePrice;
    }

    final discountPercent = item.discountPercentage;
    final discountTag = discountPercent != null && discountPercent > 0
        ? '$discountPercent% OFF'
        : null;

    final shortDescription = (item.shortDescription ?? '').trim().isEmpty
        ? (item.description ?? '').trim()
        : item.shortDescription!.trim();

    final stockLeft = item.stockQuantity ?? item.stock;
    final fastDeliveryHint = (item.deliveryType ?? '').toLowerCase();
    final isFastDelivery =
        fastDeliveryHint.contains('fast') || fastDeliveryHint.contains('same');

    return ProductModel(
      id: id,
      category: _categoryFromApiName(item.categoryName),
      name: (item.name ?? '').trim().isEmpty
          ? 'Product ${index + 1}'
          : item.name!.trim(),
      shortDescription: shortDescription.isEmpty ? null : shortDescription,
      imageUrl: _apiService.resolveImageUrl((item.images != null && item.images!.isNotEmpty) ? item.images!.first : null),
      price: finalPrice,
      originalPrice: originalPrice,
      discountTag: discountTag,
      discountPercentage: discountPercent,
      rating: null, // Note: The API response format didn't show ratings, mapping it as null
      reviewCount: null,
      reviews: const [],
      stockLeft: stockLeft,
      isFastDelivery: isFastDelivery,
      freeDelivery: item.freeDelivery,
      isBestSeller: null,
      categoryName: item.categoryName,
      categoryId: item.categoryId,
      parentCategoryId: item.parentCategoryId,
      subcategoryId: item.subcategoryId,
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

  void updateSearchQuery(String query) {
    query = query.trim();
    if (_searchQuery == query && type == ListingType.search) return;
    _searchQuery = query;
    type = ListingType.search;
    parentCategoryId = null;
    childCategoryId = null;
    _quickFilter = ProductQuickFilter.all;
    notifyListeners();
  }

  void updateVoiceSearchQuery(String query) {
    query = query.trim();
    if (_searchQuery == query && type == ListingType.voiceSearch) return;
    _searchQuery = query;
    type = ListingType.voiceSearch;
    parentCategoryId = null;
    childCategoryId = null;
    _quickFilter = ProductQuickFilter.all;
    notifyListeners();
  }

  void updateParentCategory(int parentId) {
    type = ListingType.parentCategory;
    parentCategoryId = parentId;
    childCategoryId = null;
    _searchQuery = '';
    _quickFilter = ProductQuickFilter.all;
    notifyListeners();
  }

  void updateChildCategory(int childId, {int? parentId}) {
    type = ListingType.childCategory;
    childCategoryId = childId;
    parentCategoryId = parentId;
    _searchQuery = '';
    _quickFilter = ProductQuickFilter.all;
    notifyListeners();
  }

  void setSort(ProductSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  void setQuickFilter(ProductQuickFilter filter) {
    if (_quickFilter == filter) return;
    _quickFilter = filter;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    if (!_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
