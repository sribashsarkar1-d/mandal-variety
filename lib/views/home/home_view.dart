import 'package:flutter/material.dart';
import 'home_widgets.dart';
import '../../common/drawer/app_drawer.dart';
import '../../common/appbar/primary_sliver_app_bar.dart';
import '../../common/cards/product_grid_card.dart';
import '../../common/pages/no_internet_page.dart';
import '../../core/network/network_error_utils.dart';
import '../../models/categories_model.dart';
import '../../models/global_search_model.dart';
import '../../models/product_list_model.dart';
import '../../core/product_listing/product_listing_coordinator.dart';
import '../../core/tobacco/tobacco_access_coordinator.dart';
import '../../data/models/product_model.dart';
import '../../services/api_service.dart';
import '../product_details/product_details_view.dart';
import '../product_listing/product_listing_view.dart';

class HomeView extends StatefulWidget {
  final String? initialSearchQuery;

  const HomeView({super.key, this.initialSearchQuery});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ApiService _apiService = ApiService();

  // Simulate optional profile picture (Set to a URL string or null)
  String? _profilePicUrl;
  // e.g. 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100';

  // Dummy Data for demonstration
  final List<String> _carouselImages = [
    'assets/images/onboarding/delivery_splash_1.PNG',
    'assets/images/onboarding/delivery_splash_2.PNG',
    'assets/images/onboarding/delivery_splash_3.PNG',
  ];

  final List<String> _bannerTitles = [
    'Summer Collection',
    'Winter Clearance',
    'Weekend Flash Sale',
    'New Arrivals',
  ];
  final List<String> _bannerSubtitles = [
    'Up to 50% Off on select items',
    'Save big on cold weather gear',
    'Discounts ending Sunday',
    'Latest trends and gears',
  ];
  final List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1460353581641-37baddab0fa2?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?auto=format&fit=crop&q=80&w=800',
  ];

  final List<String> _sectionTitles = [
    'Groceries You Need',
    'Fresh & Daily Picks',
    'Snack Time Favourites',
    'Beauty Must-Haves',
    'Drinks for Every Mood',
    'Dairy Essentials',
    'Everyday Essentials',
  ];

  bool _isLoadingDynamic = false;
  String? _dynamicError;
  int _retryCount = 0;
  List<CategoryItemModel> _apiCategories = const <CategoryItemModel>[];
  List<ProductModel> _apiProducts = const <ProductModel>[];
  String? _selectedCategoryName;

  String _searchQuery = '';
  bool _searchLoading = false;
  String? _searchError;
  String? _searchDidYouMean;
  List<String> _searchSuggestions = const <String>[];
  List<ProductModel> _searchResults = const <ProductModel>[];
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialSearchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchQuery = initialQuery;
    }
    _loadDynamicHomeData();

    if (initialQuery != null && initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onSearchChanged(initialQuery);
      });
    }
  }

  Future<void> _loadDynamicHomeData() async {
    if (mounted) {
      setState(() {
        _isLoadingDynamic = true;
        _dynamicError = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _apiService.getCategories(),
        _apiService.getProducts(),
      ]);

      final categories = results[0] as Categories;
      final products = results[1] as ProductList;

      final apiCategories = (categories.data ?? const <CategoryItemModel>[])
          .where((e) => (e.name ?? '').trim().isNotEmpty)
          .toList(growable: false);

      final apiProducts = (products.data ?? const <Data>[])
          .asMap()
          .entries
          .map((entry) {
             final item = entry.value;
             if ((item.categoryName == null || item.categoryName!.trim().isEmpty) && item.categoryId != null) {
                final match = apiCategories.where((c) => c.id == item.categoryId);
                if (match.isNotEmpty) {
                   item.categoryName = match.first.name;
                }
             }
             return _mapApiProduct(item, entry.key);
          })
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _apiCategories = apiCategories;
        _apiProducts = apiProducts;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dynamicError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDynamic = false;
        });
      }
    }
  }

  Future<void> _retryHomeLoad() async {
    setState(() => _retryCount++);
    await _loadDynamicHomeData();
  }

  bool get _isSearchMode => _searchQuery.trim().isNotEmpty;

  Future<void> _onSearchChanged(String query) async {
    final normalized = query.trim();
    final token = ++_searchToken;

    if (normalized.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchQuery = '';
        _searchLoading = false;
        _searchError = null;
        _searchDidYouMean = null;
        _searchSuggestions = const <String>[];
        _searchResults = const <ProductModel>[];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _searchQuery = normalized;
      _searchLoading = true;
      _searchError = null;
      _searchDidYouMean = null;
      _searchSuggestions = const <String>[];
    });

    try {
      final response = await _apiService.getGlobalSearch(query: normalized);
      if (!mounted || token != _searchToken) return;

      final results =
          (response.data?.mergedProductResults ?? const <GlobalSearchItem>[])
              .asMap()
              .entries
              .map((entry) => _mapGlobalSearchProduct(entry.value, entry.key))
              .where((e) => e != null)
              .cast<ProductModel>()
              .toList(growable: false);

      setState(() {
        _searchLoading = false;
        _searchError = response.success == true ? null : response.message;
        _searchDidYouMean = (response.didYouMean ?? '').trim().isEmpty
            ? null
            : response.didYouMean!.trim();
        _searchSuggestions = response.data?.suggestions ?? const <String>[];
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchError = e.toString();
        _searchResults = const <ProductModel>[];
      });
    }
  }

  ProductModel? _mapGlobalSearchProduct(GlobalSearchItem item, int index) {
    final id = item.id?.toString().trim() ?? '';
    final name = (item.name ?? '').trim();
    if (id.isEmpty || name.isEmpty) {
      return null;
    }

    final basePrice = double.tryParse((item.price ?? '').trim()) ?? 0.0;
    final discount = double.tryParse((item.discountPrice ?? '').trim());
    final discountPercent = item.discountPercentage;

    double finalPrice = basePrice;
    double? originalPrice;
    if (discount != null && discount > 0 && discount < basePrice) {
      finalPrice = discount;
      originalPrice = basePrice;
    }

    final discountTag = discountPercent != null && discountPercent > 0
      ? '$discountPercent% OFF'
      : null;

    final shortDescription = (item.shortDescription ?? '').trim().isNotEmpty
      ? item.shortDescription!.trim()
      : (item.description ?? '').trim();

    final deliveryType = (item.deliveryType ?? '').toLowerCase();
    final isFastDelivery =
      deliveryType.contains('fast') || deliveryType.contains('same');

    final rawImage = (item.images ?? '').trim();
    final imageUrl = rawImage.isEmpty
        ? ''
        : _apiService.resolveImageUrl(rawImage.split(',').first.trim());

    return ProductModel(
      id: id,
      category: _categoryFromApiName(item.categoryName),
      name: name,
      shortDescription: shortDescription.isEmpty ? null : shortDescription,
      imageUrl: imageUrl,
      price: finalPrice,
      originalPrice: originalPrice,
      discountTag: discountTag,
      discountPercentage: discountPercent,
      rating: null,
      reviewCount: null,
      reviews: const [],
      stockLeft: item.stockQuantity ?? item.stock,
      isFastDelivery: isFastDelivery,
      freeDelivery: item.freeDelivery,
      isBestSeller: null,
      categoryName: item.categoryName,
      categoryId: item.categoryId,
    );
  }

  ProductModel _mapApiProduct(Data item, int index) {
    final category = _categoryFromApiName(item.categoryName);
    final id = item.id?.toString() ?? 'api-product-$index';
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

    final deliveryType = (item.deliveryType ?? '').toLowerCase();
    final isFastDelivery =
        deliveryType.contains('fast') || deliveryType.contains('same');

    return ProductModel(
      id: id,
      category: category,
      name: (item.name ?? '').trim().isEmpty
          ? 'Unnamed Product'
          : item.name!.trim(),
      shortDescription: shortDescription.isEmpty ? null : shortDescription,
      imageUrl: _apiService.resolveImageUrl((item.images != null && item.images!.isNotEmpty) ? item.images!.first : null),
      price: finalPrice,
      originalPrice: originalPrice,
      discountTag: discountTag,
      discountPercentage: discountPercent,
      rating: null,
      reviewCount: null,
      stockLeft: item.stockQuantity ?? item.stock,
      isFastDelivery: isFastDelivery,
      freeDelivery: item.freeDelivery,
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

  IconData _iconFromCategoryName(String? categoryName) {
    final value = (categoryName ?? '').toLowerCase();
    if (value.contains('electronic')) return Icons.devices;
    if (value.contains('fashion')) return Icons.checkroom;
    if (value.contains('grocery')) return Icons.local_grocery_store;
    if (value.contains('beauty')) return Icons.face_retouching_natural;
    if (value.contains('book')) return Icons.menu_book;
    if (value.contains('furniture')) return Icons.chair;
    if (value.contains('toy')) return Icons.toys;
    if (value.contains('mobile')) return Icons.smartphone;
    if (value.contains('computer') || value.contains('laptop')) {
      return Icons.computer;
    }
    if (value.contains('watch')) return Icons.watch;
    if (value.contains('shoe')) return Icons.snowshoeing;
    if (value.contains('fresh')) return Icons.eco;
    if (value.contains('snack')) return Icons.fastfood;
    if (value.contains('drink')) return Icons.local_drink;
    if (value.contains('dairy')) return Icons.egg_alt;
    if (value.contains('paan') || value.contains('tobacco')) {
      return Icons.smoking_rooms_outlined;
    }
    return Icons.category;
  }

  ProductCategory? _knownCategoryFromName(String? categoryName) {
    final value = (categoryName ?? '').toLowerCase();
    if (value.contains('grocery')) return ProductCategory.grocery;
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
    return null;
  }

  List<ProductModel> get _effectiveProducts {
    final source = _apiProducts;
    if ((_selectedCategoryName ?? '').trim().isEmpty) {
      return source;
    }

    final selected = _selectedCategoryName!.toLowerCase();
    return source
        .where((product) {
          final catName = (product.categoryName ?? product.category.displayName).toLowerCase();
          return catName == selected;
        })
        .toList(growable: false);
  }

  List<ProductModel> _generateProducts(int sectionIndex) {
    final source = _effectiveProducts;
    if (source.isEmpty) return const <ProductModel>[];

    final start = (sectionIndex * 3) % source.length;
    final sectionTitle = _sectionTitles[sectionIndex % _sectionTitles.length];
    final sectionCategory = _categoryForSectionTitle(sectionTitle);

    return List.generate(4, (i) {
      final base = source[(start + i) % source.length];
      return base.copyWith(category: sectionCategory);
    });
  }

  ProductCategory _categoryForSectionTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('groc')) return ProductCategory.grocery;
    if (t.contains('fresh')) return ProductCategory.fresh;
    if (t.contains('snack')) return ProductCategory.snacks;
    if (t.contains('beauty')) return ProductCategory.beauty;
    if (t.contains('drink')) return ProductCategory.drinks;
    if (t.contains('dairy')) return ProductCategory.dairy;
    if (t.contains('shoe')) return ProductCategory.shoes;
    if (t.contains('paan') || t.contains('tobacco')) {
      return ProductCategory.tobacco;
    }
    return ProductCategory.grocery;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInitialNetworkFailure =
        !_isLoadingDynamic &&
        _apiCategories.isEmpty &&
        _apiProducts.isEmpty &&
        isNetworkError(_dynamicError);

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(
        profilePicUrl: _profilePicUrl,
        currentBottomBarIndex: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDynamicHomeData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            decelerationRate: ScrollDecelerationRate.normal,
          ),
          slivers: [
            PrimarySliverAppBar(
              searchHintText: 'Search groceries, beauty...',
              searchStaticPrefix: 'Search ',
              searchAnimatedHints: const [
                'groceries...',
                'beauty products...',
                'shoes...',
                'fresh items...',
                'snacks...',
                'drinks...',
                'dairy...',
              ],
              onSearchChanged: _onSearchChanged,
              currentBottomBarIndex: 0,
              showBackButton:
                  (widget.initialSearchQuery ?? '').trim().isNotEmpty,
            ),
            if (_isSearchMode)
              SliverToBoxAdapter(child: _buildSearchResults(theme))
            else ...[
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (hasInitialNetworkFailure)
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.75,
                        child: NoInternetPage(
                          retryCount: _retryCount,
                          onRetry: () {
                            _retryHomeLoad();
                          },
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      // Promo Carousel
                      EcommercePromoCarousel(
                        imageUrls: _carouselImages,
                        height: 180,
                        onBannerTap: () => debugPrint('Banner Tapped'),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoadingDynamic)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (_dynamicError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Material(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.onErrorContainer,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Failed to refresh categories/products. Showing available items.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onErrorContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Categories View
                      if (_apiCategories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'No categories available right now.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        EcommerceCategoryRow(categories: _buildCategoryItems()),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              // Infinite Section Builder
              if (!hasInitialNetworkFailure)
                SliverList.builder(
                  itemBuilder: (context, index) {
                    if (index % 2 == 0) {
                      // Return a product list section
                      final sectionIndex = index ~/ 2;
                      final title =
                          _sectionTitles[sectionIndex % _sectionTitles.length];
                      final products = _generateProducts(sectionIndex);

                      return Column(
                        children: [
                          EcommerceSectionTitle(
                            title: title,
                            onActionTap: () {
                              ProductListingCoordinator.instance.openListing(
                                context,
                                category: _categoryForSectionTitle(title),
                                currentBottomBarIndex: 0,
                              );
                            },
                          ),
                          if (products.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  'No products found for this category.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.58,
                                    ),
                                itemBuilder: (context, i) {
                                  final product = products[i];
                                  return ProductGridCard(
                                    key: ValueKey(product.id),
                                    product: product,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        ProductDetailsView.route(
                                          product: product,
                                          currentBottomBarIndex: 0,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      );
                    } else {
                      // Return an offer banner
                      final bannerIndex = index ~/ 2;
                      final bannerImage =
                          _bannerImages[bannerIndex % _bannerImages.length];
                      final bannerTitle =
                          _bannerTitles[bannerIndex % _bannerTitles.length];
                      final bannerSubtitle =
                          _bannerSubtitles[bannerIndex %
                              _bannerSubtitles.length];

                      return Column(
                        children: [
                          EcommerceOfferBanner(
                            title: bannerTitle,
                            subtitle: bannerSubtitle,
                            imageUrl: bannerImage,
                            onTap: () {},
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;

    final q = _searchQuery.toLowerCase();
    final matchingCategories = _apiCategories
        .where((c) => (c.name ?? '').toLowerCase().contains(q))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search results for "$_searchQuery"',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_searchDidYouMean != null) ...[
            const SizedBox(height: 8),
            Text(
              'Did you mean: $_searchDidYouMean',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_searchSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchSuggestions
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (matchingCategories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Categories',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matchingCategories.map((c) {
                return ActionChip(
                  label: Text(c.name ?? ''),
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  onPressed: () {
                    // Behave as if the user clicked the category from the main home view
                    setState(() {
                      _selectedCategoryName = c.name;
                      _searchQuery = '';
                    });
                    // Unfocus search bar
                    FocusScope.of(context).unfocus();
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            const Divider(),
          ],
          const SizedBox(height: 14),
          if (_searchLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 18),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_searchError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _searchError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_searchResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'No products found for this query.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.75),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, i) {
                final product = _searchResults[i];
                return ProductGridCard(
                  key: ValueKey(product.id),
                  product: product,
                  onTap: () {
                    Navigator.of(context).push(
                      ProductDetailsView.route(
                        product: product,
                        currentBottomBarIndex: 0,
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  List<EcommerceCategoryItem> _buildCategoryItems() {
    if (_apiCategories.isEmpty) {
      return const <EcommerceCategoryItem>[];
    }

    final allItems = <EcommerceCategoryItem>[
      EcommerceCategoryItem(
        label: 'All',
        icon: Icons.apps,
        onTap: () {
          setState(() => _selectedCategoryName = null);
        },
        backgroundColor: _selectedCategoryName == null
            ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
            : null,
      ),
    ];

    for (final cat in _apiCategories) {
      final name = (cat.name ?? '').trim();
      if (name.isEmpty) continue;
      final knownCategory = _knownCategoryFromName(name);

      allItems.add(
        EcommerceCategoryItem(
          label: name,
          icon: _iconFromCategoryName(name),
          onTap: () {
            setState(() => _selectedCategoryName = name);

            if (knownCategory == ProductCategory.tobacco) {
              TobaccoAccessCoordinator.instance.openTobaccoListing(
                context,
                currentBottomBarIndex: 0,
              );
              return;
            }

            if (knownCategory != null) {
              Navigator.of(context).push(
                ProductListingView.route(
                  category: knownCategory,
                  currentBottomBarIndex: 0,
                ),
              );
            }
          },
          backgroundColor:
              _selectedCategoryName?.toLowerCase() == name.toLowerCase()
              ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
              : null,
        ),
      );
    }

    return allItems;
  }
}
