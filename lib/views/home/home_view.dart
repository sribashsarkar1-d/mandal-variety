import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../common/pages/no_internet_page.dart';
import '../../core/network/network_error_utils.dart';
import '../../core/location/address_location_coordinator.dart';
import '../../core/cart/cart_coordinator.dart';
import '../../models/category_hierarchy_model.dart';
import '../../models/banners_model.dart';
import '../../models/product_list_model.dart';
import '../../services/api_service.dart';
import '../../services/api_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../common/cards/product_grid_card.dart';
import '../../widgets/product_card_widget.dart';
import '../../common/searchbar/app_search_bar.dart';
import '../../common/buttons/cart_icon_button.dart';
import '../product_details/product_details_view.dart';
import '../product_listing/product_listing_view.dart';
import '../../viewmodels/product_listing_viewmodel.dart';
import '../../data/models/product_model.dart';

class HomeView extends StatefulWidget {
  final String? initialSearchQuery;

  const HomeView({super.key, this.initialSearchQuery});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ApiService _apiService = ApiService();

  _HomePayload? _cachedPayload;
  bool _isLoading = true;
  Object? _error;
  int _retryCount = 0;
  String _addressDisplay = 'Detecting location...';

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final cache = await AddressLocationCoordinator.instance.getCache();
      if (cache.selectedAddressId.isNotEmpty) {
        if (cache.selectedAddressId == 'auto' && cache.autoLocation != null) {
          setState(() {
            _addressDisplay = cache.autoLocation!.formattedAddress ?? 'Current Location';
          });
        } else {
          final manual = cache.manualAddresses.firstWhere(
            (e) => e.id == cache.selectedAddressId,
          );
          setState(() {
            final addr = manual.addressLine.replaceAll(',', '').trim();
            _addressDisplay = addr.isNotEmpty ? manual.addressLine : manual.label;
          });
        }
      } else {
        setState(() {
          _addressDisplay = 'Select an address';
        });
      }
    } catch (_) {
      setState(() {
        _addressDisplay = 'Select an address';
      });
    }
  }

  String _getFriendlyErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (isNetworkError(e)) {
      return 'No internet connection. Please check your network and try again.';
    } else if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Request timed out. Please try again.';
    } else if (msg.contains('server error') || msg.contains('500') || msg.contains('502') || msg.contains('503') || msg.contains('504')) {
      return 'Server is temporarily unavailable. Please try again.';
    } else if (e is FormatException || msg.contains('format') || msg.contains('json') || msg.contains('expected object')) {
      return 'Unable to load data. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }



  void _updatePayload(CategoryHierarchyModel hierarchy, BannersModel banners, ProductList products) {
    final parents = (hierarchy.data ?? <HierarchyParentModel>[])
        .where((item) => (item.isActive ?? 1) == 1)
        .toList();

    final bannerItems = (banners.data ?? <BannerItemModel>[])
        .where((item) => (item.isActive ?? 1) == 1)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    final productItems = products.data ?? <Data>[];

    if (mounted) {
      setState(() {
        _cachedPayload = _HomePayload(
          parents: parents,
          banners: bannerItems,
          products: productItems,
        );
      });
    }
  }

  Future<void> _loadHomeData() async {
    if (mounted && _cachedPayload == null) {
      setState(() { _isLoading = true; _error = null; });
    }

    final cacheService = ApiCacheService.instance;
    await cacheService.init();

    // 1. Try to load from cache
    final cachedHierarchyJson = await cacheService.getCachedJson('home_hierarchy');
    final cachedBannersJson = await cacheService.getCachedJson('home_banners');
    final cachedProductsJson = await cacheService.getCachedJson('home_products');

    if (cachedHierarchyJson != null && cachedBannersJson != null && cachedProductsJson != null) {
      try {
        final hierarchy = CategoryHierarchyModel.fromJson(cachedHierarchyJson);
        final banners = BannersModel.fromJson(cachedBannersJson);
        final products = ProductList.fromJson(cachedProductsJson);
        
        _updatePayload(hierarchy, banners, products);
        if (mounted) setState(() { _isLoading = false; });
      } catch (_) {}
    }

    // 2. Fetch fresh data in the background
    try {
      final hierarchyFuture = _apiService.getCategoryHierarchy()
          .then<CategoryHierarchyModel?>((v) => v)
          .catchError((_) => null);
      
      final bannersFuture = _apiService.getBanners()
          .then<BannersModel?>((v) => v)
          .catchError((_) => null);

      final productsFuture = _apiService.getProducts()
          .then<ProductList?>((v) => v)
          .catchError((_) => null);

      final results = await Future.wait([
        hierarchyFuture,
        bannersFuture,
        productsFuture,
      ]);

      final hierarchy = results[0] as CategoryHierarchyModel?;
      final banners = results[1] as BannersModel?;
      final products = results[2] as ProductList?;

      if (hierarchy == null && banners == null && products == null) {
        throw Exception('Failed to load any home data');
      }

      final finalHierarchy = hierarchy ?? (_cachedPayload != null ? CategoryHierarchyModel(data: _cachedPayload!.parents) : CategoryHierarchyModel());
      final finalBanners = banners ?? (_cachedPayload != null ? BannersModel(data: _cachedPayload!.banners) : BannersModel());
      final finalProducts = products ?? (_cachedPayload != null ? ProductList(data: _cachedPayload!.products) : ProductList());

      if (hierarchy?.data?.isNotEmpty == true) {
        await cacheService.cacheJson('home_hierarchy', hierarchy!.toJson());
      }
      if (banners?.data?.isNotEmpty == true) {
        await cacheService.cacheJson('home_banners', banners!.toJson());
      }
      if (products?.data?.isNotEmpty == true) {
        await cacheService.cacheJson('home_products', products!.toJson());
      }

      _updatePayload(finalHierarchy, finalBanners, finalProducts);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_cachedPayload == null) {
          setState(() {
            _error = e;
            _isLoading = false;
          });
        } else {
          // If we have cached data, don't show full error screen, just a snackbar
          setState(() { _isLoading = false; _error = null; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getFriendlyErrorMessage(e)),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _retryHomeLoad,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _refresh() async {
    if (_isLoading) return;
    await _loadHomeData();
    _loadAddress();
  }

  Future<void> _retryHomeLoad() async {
    if (_isLoading) return;
    setState(() => _retryCount++);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildHeaderSliver(theme),
              _buildStateContent(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF1B5E20), // Fresh green Mandal Variety color
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Location & Icons
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Deliver to',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                        ],
                      ),
                      Text(
                        _addressDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Icons (Notification, Cart)
                // Notification (hidden if no central system, but let's put an icon for UI, or hide badge)
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () {},
                ),
                // Cart Icon using existing coordinator
                ValueListenableBuilder<int>(
                  valueListenable: CartCoordinator.instance.itemCount,
                  builder: (context, count, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                          onPressed: () {
                            CartCoordinator.instance.openCart(context);
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  count > 99 ? '99+' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Brand Area
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.eco, color: Color(0xFF1B5E20), size: 32), // Logo placeholder
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mandal Variety',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Everything You Need\nIn One App!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.electric_moped, color: Color(0xFF1B5E20), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Fast & Safe\nDelivery',
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: AppSearchBar(
                hintText: "Search for 'shampoo', 'moisturizer'...",
                animatedHints: const ["'shampoo'...", "'moisturizer'...", "'oil'..."],
                onSubmitted: (q) {
                  Navigator.of(context).push(
                    ProductListingView.route(
                      type: ListingType.search,
                      initialSearchQuery: q,
                    ),
                  );
                },
                onVoiceSubmitted: (q) {
                  Navigator.of(context).push(
                    ProductListingView.route(
                      type: ListingType.voiceSearch,
                      initialSearchQuery: q,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme) {
    if (_isLoading && _cachedPayload == null) {
      return SliverToBoxAdapter(child: _buildLoadingState(theme));
    }

    if (_cachedPayload != null) {
      final payload = _cachedPayload!;
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 16),
          _buildParentCategoryCarousel(payload.parents, theme),
          const SizedBox(height: 24),
          if (payload.banners.isNotEmpty) _buildBannerCarousel(payload.banners, theme),
          const SizedBox(height: 24),
          _buildQuickActions(theme),
          const SizedBox(height: 16),
          ..._buildCategorySections(payload.parents, theme),
          const SizedBox(height: 16),
          if (payload.products.isNotEmpty) _buildTopPicks(payload.products, theme),
          const SizedBox(height: 32),
        ]),
      );
    }

    if (_error != null) {
      if (isNetworkError(_error)) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: NoInternetPage(
            retryCount: _retryCount,
            onRetry: _retryHomeLoad,
          ),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(
          message: _getFriendlyErrorMessage(_error!),
          onRetry: _retryHomeLoad,
        ),
      );
    }

    return SliverFillRemaining(
      hasScrollBody: false,
      child: _ErrorState(message: 'No data found.', onRetry: _retryHomeLoad),
    );
  }

  Widget _buildParentCategoryCarousel(List<HierarchyParentModel> parents, ThemeData theme) {
    if (parents.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: parents.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  ProductListingView.route(type: ListingType.all),
                );
              },
              child: _buildCategoryItem('All', null, Icons.grid_view, theme),
            );
          }
          final parent = parents[index - 1];
          final imageUrl = _apiService.resolveImageUrl(parent.image);
          return GestureDetector(
            onTap: () {
              if (parent.id != null) {
                Navigator.of(context).push(
                  ProductListingView.route(
                    type: ListingType.parentCategory,
                    parentCategoryId: parent.id,
                  ),
                );
              }
            },
            child: _buildCategoryItem(parent.name ?? 'Unknown', imageUrl, _getCategoryIcon(parent.name), theme),
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem(String name, String? imageUrl, IconData fallbackIcon, ThemeData theme) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Icon(fallbackIcon, color: theme.colorScheme.primary),
                    ),
                  )
                : Icon(fallbackIcon, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel(List<BannerItemModel> banners, ThemeData theme) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = _apiService.resolveImageUrl(banner.image);
          return GestureDetector(
            onTap: () {
              if (banner.buttonLink != null && banner.buttonLink!.isNotEmpty) {
                  // For now, route to generic products if link is /products
                 if (banner.buttonLink!.contains('products')) {
                    Navigator.of(context).push(
                      ProductListingView.route(type: ListingType.all),
                    );
                 }
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 40)),
                    ),
                  // If we wanted to draw text over the image, we could do it here.
                  // But usually banners have text baked in.
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    final actions = [
      {'title': 'Offers', 'icon': Icons.local_offer, 'color': Colors.pinkAccent},
      {'title': 'Best Sellers', 'icon': Icons.star, 'color': Colors.deepPurpleAccent},
      {'title': 'Flash Deals', 'icon': Icons.flash_on, 'color': Colors.orangeAccent},
      {'title': 'New Arrivals', 'icon': Icons.new_releases, 'color': Colors.green},
      {'title': 'Premium', 'icon': Icons.verified, 'color': Colors.blueAccent},
      {'title': 'Combo Packs', 'icon': Icons.card_giftcard, 'color': Colors.redAccent},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () {
               // Route to product listing as fallback
               Navigator.of(context).push(
                 ProductListingView.route(type: ListingType.all),
               );
            },
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action['icon'] as IconData, color: action['color'] as Color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action['title'] as String,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategorySections(List<HierarchyParentModel> parents, ThemeData theme) {
    final widgets = <Widget>[];
    
    for (final parent in parents) {
      if (parent.children == null || parent.children!.isEmpty) continue;

      final children = parent.children!.where((c) => (c.isActive ?? 1) == 1).toList();
      if (children.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: _apiService.resolveImageUrl(parent.image).isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(_apiService.resolveImageUrl(parent.image)),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.5),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parent.name ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          if (parent.description != null && parent.description!.isNotEmpty)
                            Text(
                              parent.description!,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (parent.id != null) {
                          Navigator.of(context).push(
                            ProductListingView.route(
                              type: ListingType.parentCategory,
                              parentCategoryId: parent.id,
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Row(
                        children: [
                          Text('View All', style: TextStyle(fontSize: 12, color: Colors.white)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                  const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final child = children[idx];
                    final imageUrl = _apiService.resolveImageUrl(child.image);
                    return GestureDetector(
                      onTap: () {
                         Navigator.of(context).push(
                           ProductListingView.route(
                             type: ListingType.childCategory,
                             childCategoryId: child.id,
                             parentCategoryId: parent.id,
                           ),
                         );
                      },
                      child: SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.category, color: Colors.grey),
                                    )
                                  : const Icon(Icons.category, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              child.name ?? '',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildTopPicks(List<Data> products, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: const CachedNetworkImageProvider('https://images.unsplash.com/photo-1604719312566-8912e9227c6a?q=80&w=2000&auto=format&fit=crop'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.5),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Picks for You',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      'Handpicked Products Just for You',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      ProductListingView.route(type: ListingType.all),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Row(
                    children: [
                      Text('See All', style: TextStyle(fontSize: 12, color: Colors.white)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              final image = _apiService.resolveImageUrl((product.images != null && product.images!.isNotEmpty) ? product.images!.first : null);
              final price = product.discountPrice != null && product.discountPrice! > 0
                  ? 'Rs ${product.discountPrice}'
                  : 'Rs ${product.price ?? '0'}';
              final categoryName = (product.parentCategoryName ?? '').trim().isEmpty
                  ? (product.categoryName ?? 'Uncategorized').trim()
                  : product.parentCategoryName!.trim();

              // Calculate discount % to show
              String? discountBadge;
              if (product.discountPercentage != null && product.discountPercentage! > 0) {
                 discountBadge = '${product.discountPercentage}% OFF';
              }

              return ProductCardWidget(
                productId: product.id!,
                product: product,
                name: (product.name ?? '').trim().isEmpty ? 'Unnamed Product' : product.name!.trim(),
                priceText: price,
                oldPriceText: product.discountPrice != null && product.discountPrice! > 0
                    ? 'Rs ${product.price}'
                    : null,
                categoryName: categoryName,
                imageUrl: image,
                discountBadgeText: discountBadge,
                rating: product.averageRating,
                reviewCount: product.reviewCount,
                onTap: () {
                  if (product.id == null) return;
                  final mappedProduct = ProductModel(
                    id: product.id!.toString(),
                    category: _getCategoryEnum(product.parentCategoryName ?? product.categoryName),
                    name: (product.name ?? '').trim().isEmpty ? 'Unnamed Product' : product.name!.trim(),
                    imageUrl: image,
                    price: product.discountPrice != null && product.discountPrice! > 0
                        ? double.tryParse(product.discountPrice.toString()) ?? 0.0
                        : double.tryParse(product.price?.toString() ?? '0') ?? 0.0,
                    originalPrice: product.discountPrice != null && product.discountPrice! > 0
                        ? double.tryParse(product.price?.toString() ?? '0') ?? 0.0
                        : null,
                    discountTag: discountBadge,
                    rating: product.averageRating,
                    reviewCount: product.reviewCount,
                    reviews: const [],
                    stockLeft: product.stockQuantity ?? product.stock,
                    isFastDelivery: null,
                    isBestSeller: null,
                  );
                  Navigator.of(context).push(
                    ProductDetailsView.route(
                      product: mappedProduct,
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

  IconData _getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.category;
    final normalized = categoryName.trim().toLowerCase();
    if (normalized.contains('beauty') || normalized.contains('care')) return Icons.face_retouching_natural;
    if (normalized.contains('hair')) return Icons.face_2;
    if (normalized.contains('home')) return Icons.home;
    if (normalized.contains('grocer')) return Icons.local_grocery_store;
    if (normalized.contains('baby')) return Icons.child_care;
    return Icons.category;
  }

  ProductCategory _getCategoryEnum(String? categoryName) {
    if (categoryName == null) return ProductCategory.grocery;
    final normalized = categoryName.trim().toLowerCase();
    if (normalized.contains('beauty')) return ProductCategory.beauty;
    if (normalized.contains('shoe') || normalized.contains('footwear')) return ProductCategory.shoes;
    if (normalized.contains('fresh') || normalized.contains('vegetable')) return ProductCategory.fresh;
    if (normalized.contains('snack')) return ProductCategory.snacks;
    if (normalized.contains('drink') || normalized.contains('beverage')) return ProductCategory.drinks;
    if (normalized.contains('dairy')) return ProductCategory.dairy;
    if (normalized.contains('paan') || normalized.contains('tobacco')) return ProductCategory.tobacco;
    return ProductCategory.grocery;
  }

  Widget _buildLoadingState(ThemeData theme) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _HomePayload {
  const _HomePayload({
    required this.parents,
    required this.banners,
    required this.products,
  });

  final List<HierarchyParentModel> parents;
  final List<BannerItemModel> banners;
  final List<Data> products;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
  