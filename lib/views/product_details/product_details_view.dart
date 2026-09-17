import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/appbar/common_search_cart_app_bar.dart';
import '../../common/bottombar/common_bottom_bar.dart';
import '../../common/buttons/app_button.dart';
import '../../common/cards/app_card.dart';
import '../../common/cards/product_grid_card.dart';
import '../../common/image_viewer/zoomable_image_viewer.dart';
import '../../common/snackbars/app_snackbar.dart';
import '../../common/pages/no_internet_page.dart';
import '../../core/auth/auth_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../core/utils/platform_helper.dart';
import '../../data/models/product_model.dart';
import '../../models/list_review_model.dart' as review_model;
import '../../data/repositories/hive_cart_repository.dart';
import '../../data/repositories/hive_wishlist_repository.dart';
import '../../viewmodels/product_details_viewmodel.dart';
import '../../viewmodels/product_listing_viewmodel.dart';
import '../cart/cart_view.dart';
import '../home/home_widgets.dart';
import '../main/main_view.dart';
import '../product_listing/product_listing_view.dart';
import 'reviews_view.dart';
import 'widgets/review_display_widgets.dart';
import 'widgets/product_details_skeleton.dart';

import 'package:cached_network_image/cached_network_image.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = source.trim();
  if (value.isEmpty) {
    return const AssetImage(_fallbackImageAsset);
  }
  if (value.startsWith('assets/')) {
    return AssetImage(value);
  }
  if (_isHttpUrl(value)) {
    return CachedNetworkImageProvider(value);
  }
  return const AssetImage(_fallbackImageAsset);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ProductDetailsView
// ═══════════════════════════════════════════════════════════════════════════════

class ProductDetailsView extends StatefulWidget {
  final ProductModel product;
  final int currentBottomBarIndex;

  const ProductDetailsView({
    super.key,
    required this.product,
    required this.currentBottomBarIndex,
  });

  static Route<void> route({
    required ProductModel product,
    required int currentBottomBarIndex,
  }) {
    Widget builder(BuildContext _) => ProductDetailsView(
      product: product,
      currentBottomBarIndex: currentBottomBarIndex,
    );

    return PlatformHelper.isIOS
        ? CupertinoPageRoute<void>(builder: builder)
        : MaterialPageRoute<void>(builder: builder);
  }

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

// ═══════════════════════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductDetailsViewState extends State<ProductDetailsView>
    with TickerProviderStateMixin {
  late final ProductDetailsViewModel _vm;
  late final PageController _pageController;
  late final AnimationController _firePulseController;
  late final Animation<double> _firePulse;

  bool _descExpanded = true;
  int _activeImageIndex = 0;

  bool _wishlistPulse = false;
  bool _addToCartPulse = false;
  bool _isAddingToCart = false;
  bool _sharePulse = false;
  bool _shareShown = false;

  // Skeleton stays visible for a minimum of 1.8 s (static timing).
  // Switch to API loading duration once live network calls are in place.
  bool _skeletonVisible = true;
  Timer? _skeletonTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _vm = ProductDetailsViewModel(
      product: widget.product,
      cartRepository: HiveCartRepository(),
      wishlistRepository: HiveWishlistRepository(),
    );
    _pageController = PageController();
    _vm.init();

    // Enforce minimum skeleton visibility so the shimmer is readable
    _skeletonTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _skeletonVisible = false);
    });

    _firePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _firePulse = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _firePulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _firePulseController.dispose();
    _pageController.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ── Pulse helpers ─────────────────────────────────────────────────────────

  void _pulseWishlist() {
    if (!mounted) return;
    setState(() => _wishlistPulse = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _wishlistPulse = false);
    });
  }

  void _pulseAddToCart() {
    if (!mounted) return;
    setState(() => _addToCartPulse = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _addToCartPulse = false);
    });
  }

  void _pulseShare() {
    if (!mounted) return;
    setState(() => _sharePulse = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _sharePulse = false);
    });
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _handleToggleWishlist() async {
    final allowed = await handleProtectedAction(context);
    if (!allowed) return;
    HapticFeedback.selectionClick();
    _pulseWishlist();
    final result = await _vm.toggleWishlist();
    if (!mounted) return;
    if (result.success) {
      AppSnackbar.success(context, result.message);
    } else {
      AppSnackbar.warning(context, result.message);
    }
  }

  Future<void> _handleAddToCart() async {
    if (_isAddingToCart || _vm.isInCart) return;
    final allowed = await handleProtectedAction(context);
    if (!allowed) return;
    HapticFeedback.lightImpact();
    _pulseAddToCart();
    setState(() => _isAddingToCart = true);
    try {
      final result = await _vm.addToCart();
      if (!mounted) return;
      if (result.success) {
        AppSnackbar.success(context, result.message);
      } else {
        AppSnackbar.warning(context, result.message);
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _handleShare() {
    if (_shareShown) return;
    _shareShown = true;
    HapticFeedback.selectionClick();
    _pulseShare();
    AppSnackbar.info(context, 'Sharing coming soon');
    Future<void>.delayed(const Duration(seconds: 5), () {
      _shareShown = false;
    });
  }

  Future<void> _goToCart() async {
    final allowed = await handleProtectedAction(context);
    if (!allowed || !mounted) return;

    Navigator.of(context).push(
      PlatformHelper.isIOS
          ? CupertinoPageRoute<void>(
              builder: (_) =>
                  CartView(currentBottomBarIndex: widget.currentBottomBarIndex),
            )
          : MaterialPageRoute<void>(
              builder: (_) =>
                  CartView(currentBottomBarIndex: widget.currentBottomBarIndex),
            ),
    );
  }

  Future<void> _incrementQty() async {
    HapticFeedback.selectionClick();
    await _vm.incrementQuantity();
  }

  Future<void> _decrementQty() async {
    if (_vm.quantity <= 1) return;
    HapticFeedback.selectionClick();
    await _vm.decrementQuantity();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW >= 600;

    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F9F4), // Light Green Background
          appBar: CommonSearchCartAppBar(
            searchHintText: 'Search ${widget.product.category.searchHint}...',
            searchStaticPrefix: 'Search ',
            currentBottomBarIndex: widget.currentBottomBarIndex,
            showBackButton: true,
          ),
          bottomNavigationBar: CommonBottomBar(
            currentIndex: widget.currentBottomBarIndex,
            onTap: (i) {
              if (i == widget.currentBottomBarIndex) {
                Navigator.of(context).maybePop();
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => MainView(initialIndex: i)),
                  (_) => false,
                );
              }
            },
            items: [
              CommonBottomBarItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
              ),
              CommonBottomBarItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: 'Wishlist',
              ),
              CommonBottomBarItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Orders',
              ),
            ],
          ),
          body: _buildBody(theme, isWide),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, bool isWide) {
    final onSurface = theme.colorScheme.onSurface;

    if (_vm.isLoading || _skeletonVisible) {
      return const ProductDetailsSkeleton();
    }

    if (_vm.hasError) {
      if (_vm.isNetworkError) {
        return NoInternetPage(
          retryCount: _retryCount,
          onRetry: () {
            setState(() => _retryCount++);
            _vm.init();
          },
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _vm.errorMessage ?? 'Something went wrong.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final stockLeft = _vm.displayStockLeft;
    final outOfStock = stockLeft != null && stockLeft <= 0;

    if (isWide) return _wideLayout(theme, outOfStock);
    return _narrowLayout(theme, outOfStock);
  }

  // ── Mobile single-column ─────────────────────────────────────────────────


  Widget _narrowLayout(ThemeData theme, bool outOfStock) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageSection(tabletMode: false),
                  _infoSection(theme, tabletMode: false),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _featuresRow()),
        if (_vm.hasProductDetailsTableData)
          SliverToBoxAdapter(child: _productInfoCard(theme)),
        if ((_vm.productDescription ?? '').isNotEmpty)
          SliverToBoxAdapter(child: _descriptionCard(theme)),
        if (_vm.similarProducts.isNotEmpty) ..._youMightAlsoLikeSlivers(),
        if (_vm.recommendedProducts.isNotEmpty) ..._recommendedSlivers(),
        if (_vm.categorySearchProducts.isNotEmpty)
          ..._categorySearchSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: 104)),
      ],
    );
  }

  // ── Tablet two-column ────────────────────────────────────────────────────


  Widget _wideLayout(ThemeData theme, bool outOfStock) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _imageSection(tabletMode: true),
                  ),
                  Expanded(
                    flex: 5,
                    child: _infoSection(theme, tabletMode: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _featuresRow()),
        if (_vm.hasProductDetailsTableData)
          SliverToBoxAdapter(child: _productInfoCard(theme)),
        if ((_vm.productDescription ?? '').isNotEmpty)
          SliverToBoxAdapter(child: _descriptionCard(theme)),
        if (_vm.similarProducts.isNotEmpty) ..._youMightAlsoLikeSlivers(),
        if (_vm.recommendedProducts.isNotEmpty) ..._recommendedSlivers(),
        if (_vm.categorySearchProducts.isNotEmpty)
          ..._categorySearchSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: 104)),
      ],
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _imageSection({bool tabletMode = false}) {
    return _ImageGallery(
      imageUrls: _vm.imageUrls,
      pageController: _pageController,
      activeIndex: _activeImageIndex,
      onPageChanged: (i) => setState(() => _activeImageIndex = i),
      onZoomTap: (url) => ZoomableImageViewer.show(
        context,
        imageProvider: _resolveImageProvider(url),
      ),
      isWishlisted: _vm.isWishlisted,
      wishlistPulse: _wishlistPulse,
      onWishlistTap: _handleToggleWishlist,
      sharePulse: _sharePulse,
      onShareTap: _handleShare,
      discountTag: _vm.displayDiscountTag,
      aspectRatio: tabletMode ? 0.85 : 0.95,
    );
  }


  Widget _featuresRow() {
    final features = [
      {'icon': Icons.verified_user_outlined, 'text': '100% Original'},
      {'icon': Icons.local_shipping_outlined, 'text': 'Fast Delivery'},
      {'icon': Icons.assignment_return_outlined, 'text': 'Easy Returns'},
      {'icon': Icons.payment_outlined, 'text': 'Secure Payment'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: features.map((f) => Expanded(
            child: Column(
              children: [
                Icon(f['icon'] as IconData, color: const Color(0xFF388E3C), size: 28),
                const SizedBox(height: 8),
                Text(
                  f['text'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _productInfoCard(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final successColor = const Color(0xFF388E3C);
    final errorColor = const Color(0xFFFF3366);
    final stockLeft = _vm.displayStockLeft;
    final outOfStock = stockLeft != null && stockLeft <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined, color: Color(0xFF388E3C), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Product Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProductDetailsTable(
              shortDescription: _vm.productShortDescription,
              categoryLabel: _vm.displayCategoryLabel,
              brand: _vm.productBrand,
              unitLabel: _vm.productUnitLabel,
              couponApplicable: _vm.productCouponApplicable,
              discountPercentage: _vm.productDiscountPercentage,
              inStock: _vm.productInStock,
              sku: _vm.displaySku,
              maxOrderQuantity: _vm.productMaxOrderQuantity,
              minOrderQuantity: _vm.productMinOrderQuantity,
              estimatedDeliveryTime: _vm.productEstimatedDeliveryTime,
              expiryDate: _vm.productExpiryDate,
              manufacturingDate: _vm.productManufacturingDate,
              countryOfOrigin: _vm.productCountryOfOrigin,
              deliveryType: _vm.productDeliveryType,
              deliveryCharge: _vm.productDeliveryCharge,
              freeDelivery: _vm.productFreeDelivery,
              weight: _vm.displayWeight,
              attributes: _vm.displayAttributes,
              stockLeft: stockLeft,
              outOfStock: outOfStock,
              dividerColor: theme.dividerColor,
              onSurface: onSurface,
              successColor: successColor,
              errorColor: errorColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF388E3C), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Description',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _descExpanded = !_descExpanded),
                  child: Text(
                    _descExpanded ? 'Read Less ^' : 'Read More v',
                    style: const TextStyle(color: Color(0xFF388E3C), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _vm.productDescription!,
              maxLines: _descExpanded ? null : 3,
              overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13, height: 1.5),
            ),
            if (_descExpanded) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.stars, color: Color(0xFF388E3C), size: 16),
                            const SizedBox(width: 8),
                            const Text('Key Benefits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...['Non-sticky formula', 'Enriched with Olive Oil & Vitamin E', 'Deep scalp nourishment', 'Helps maintain healthy and shiny hair', 'Suitable for daily use', 'Light and easy-to-apply texture'].map((benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF388E3C), size: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(benefit, style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)))),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 120, color: Colors.grey.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book, color: Color(0xFF388E3C), size: 16),
                            const SizedBox(width: 8),
                            const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Apply an adequate amount to the scalp and hair. Massage gently and leave for a few hours or overnight before washing if desired.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF546E7A), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoSection(ThemeData theme, {bool tabletMode = false}) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primary = const Color(0xFF388E3C); // Green
    
    final stockLeft = _vm.displayStockLeft;
    final outOfStock = stockLeft != null && stockLeft <= 0;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(tabletMode ? 24 : 16, tabletMode ? 0 : 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _vm.displayCategoryLabel,
              style: const TextStyle(
                color: Color(0xFF388E3C),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            _vm.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle / Bengali Text (Mocked for style as per image, use description or hardcode if needed, but since it's dynamic we can just use the short description or leave it)
          if ((_vm.productShortDescription ?? '').isNotEmpty)
            Text(
              _vm.productShortDescription!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF546E7A),
              ),
            ),
          const SizedBox(height: 12),
          
          // Rating
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AllReviewsView(product: widget.product),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '${_vm.reviewAverageRating?.toStringAsFixed(1) ?? "0.0"} (${_vm.reviewCount} reviews)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF546E7A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF546E7A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppCurrency.format(_vm.displayPrice, freeForZero: false),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B5E20),
                  fontSize: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (_vm.displayOriginalPrice != null)
                Text(
                  AppCurrency.format(_vm.displayOriginalPrice!, freeForZero: false),
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_vm.displayOriginalPrice != null) const SizedBox(width: 8),
              if (_vm.displayDiscountTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _vm.displayDiscountTag!,
                    style: const TextStyle(
                      color: Color(0xFFFF3366),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Stock and Qty
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        outOfStock ? Icons.cancel : Icons.check_circle,
                        color: outOfStock ? const Color(0xFFFF3366) : const Color(0xFF388E3C),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outOfStock ? 'Out of Stock' : 'In Stock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: outOfStock ? const Color(0xFFFF3366) : const Color(0xFF388E3C),
                              ),
                            ),
                            if (!outOfStock && stockLeft != null)
                              Text(
                                '$stockLeft available',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!outOfStock)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Color(0xFF388E3C), size: 20),
                        onPressed: _vm.quantity > 1 ? _decrementQty : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Container(
                        width: 28,
                        alignment: Alignment.center,
                        child: Text(
                          '${_vm.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF388E3C), size: 20),
                        onPressed: _incrementQty,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
            ],
          ),
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAddingToCart || _vm.isInCart ? _goToCart : _handleAddToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _isAddingToCart 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_vm.isInCart ? Icons.shopping_bag : Icons.shopping_cart_outlined, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _vm.isInCart ? 'Go to Cart' : 'Add to Cart',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleToggleWishlist,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFEEEEEE)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      _vm.isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: const Color(0xFFFF3366),
                      size: 20,
                    ),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add to Wishlist',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
      ),
    );
  }

  ReviewDisplayEntry _mapApiReview(review_model.Data review) {
    final rating = (review.rating ?? 0).clamp(1, 5);
    final title = (review.title ?? '').trim();
    final comment = (review.comment ?? '').trim();
    final body = [
      if (title.isNotEmpty) title,
      if (comment.isNotEmpty) comment,
    ].join(' - ').trim();

    return ReviewDisplayEntry(
      id: review.id?.toString() ?? '',
      name: (review.userName ?? '').trim().isEmpty
          ? 'Anonymous User'
          : review.userName!.trim(),
      rating: rating,
      text: body.isEmpty ? 'No review text provided.' : body,
      title: title,
      isVerified: true,
      daysAgo: _daysAgoFromIso(review.createdAt),
      createdAt: review.createdAt,
    );
  }

  int _daysAgoFromIso(String? iso) {
    if ((iso ?? '').trim().isEmpty) return 0;
    final parsed = DateTime.tryParse(iso!.trim());
    if (parsed == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(parsed.toLocal()).inDays;
    return diff < 0 ? 0 : diff;
  }

  SliverToBoxAdapter _similarHeader(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: EcommerceSectionTitle(
          title: 'You might also like',
          actionText: 'See All',
          onActionTap: () {
            Navigator.of(context).push(
              ProductListingView.route(
                childCategoryId: widget.product.categoryId,
                type: ListingType.related,
                currentBottomBarIndex: widget.currentBottomBarIndex,
              ),
            );
          },
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Section sliver groups ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  List<Widget> _youMightAlsoLikeSlivers() => [
    _similarHeader(Theme.of(context)),
    SliverToBoxAdapter(child: _productCarousel(_vm.similarProducts)),
  ];

  List<Widget> _recommendedSlivers() => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: EcommerceSectionTitle(
          title: 'Recommended for You',
          actionText: 'See All',
          onActionTap: () {
            Navigator.of(context).push(
              ProductListingView.route(
                type: ListingType.all,
                currentBottomBarIndex: widget.currentBottomBarIndex,
              ),
            );
          },
        ),
      ),
    ),
    SliverToBoxAdapter(child: _productCarousel(_vm.recommendedProducts)),
  ];

  List<Widget> _categorySearchSlivers() => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: EcommerceSectionTitle(
          title: 'Because you searched ${widget.product.category.displayName}',
          actionText: 'See All',
          onActionTap: () {
            Navigator.of(context).push(
              ProductListingView.route(
                childCategoryId: widget.product.categoryId,
                type: ListingType.related,
                currentBottomBarIndex: widget.currentBottomBarIndex,
              ),
            );
          },
        ),
      ),
    ),
    SliverToBoxAdapter(child: _productCarousel(_vm.categorySearchProducts)),
  ];

  Widget _productCarousel(List<ProductModel> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 280,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final p = products[i];
            return SizedBox(
              width: 164,
              child: ProductGridCard(
                key: ValueKey(p.id),
                product: p,
                onTap: () => Navigator.of(context).push(
                  ProductDetailsView.route(
                    product: p,
                    currentBottomBarIndex: widget.currentBottomBarIndex,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _positionedBottomBar(ThemeData theme, bool outOfStock) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _FrostedBottomBar(
        enabled: !outOfStock,
        inCart: _vm.isInCart,
        quantity: _vm.quantity,
        canDecrement: _vm.quantity > 1,
        isLoading: _isAddingToCart,
        pulse: _addToCartPulse,
        onAddToCart: _handleAddToCart,
        onIncrement: _incrementQty,
        onDecrement: _decrementQty,
        onGoToCart: _goToCart,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Image Gallery — rounded carousel with floating overlays
// ═══════════════════════════════════════════════════════════════════════════════


class _ImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final PageController pageController;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onZoomTap;
  final bool isWishlisted;
  final bool wishlistPulse;
  final VoidCallback onWishlistTap;
  final bool sharePulse;
  final VoidCallback onShareTap;
  final String? discountTag;
  final double aspectRatio;

  const _ImageGallery({
    required this.imageUrls,
    required this.pageController,
    required this.activeIndex,
    required this.onPageChanged,
    required this.onZoomTap,
    required this.isWishlisted,
    required this.wishlistPulse,
    required this.onWishlistTap,
    required this.sharePulse,
    required this.onShareTap,
    required this.discountTag,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.isEmpty ? const <String>[] : imageUrls;
    
    return Column(
      children: [
        // Main Image
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: urls.isNotEmpty
                      ? PageView.builder(
                          controller: pageController,
                          itemCount: urls.length,
                          onPageChanged: onPageChanged,
                          itemBuilder: (_, index) {
                            final url = urls[index];
                            return GestureDetector(
                              onTap: () => onZoomTap(url),
                              child: Container(
                                color: Colors.white,
                                child: Image(
                                  image: _resolveImageProvider(url),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 48, color: Colors.grey)),
                ),
              ),
              // Index Badge
              if (urls.length > 1)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${activeIndex + 1} / ${urls.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Thumbnails
        if (urls.length > 1)
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              itemBuilder: (context, index) {
                final isActive = index == activeIndex;
                return GestureDetector(
                  onTap: () {
                    pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 64,
                    padding: EdgeInsets.all(isActive ? 3 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isActive ? const Color(0xFF388E3C) : Colors.grey.withOpacity(0.2),
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(isActive ? 10 : 8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isActive ? 6 : 8),
                      child: Container(
                        color: Colors.white,
                        child: Image(
                          image: _resolveImageProvider(urls[index]),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}


class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool pulse;
  final Color surfaceColor;
  final Color iconColor;

  const _ActionCircle({
    required this.icon,
    required this.onTap,
    required this.pulse,
    required this.surfaceColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pulse ? 0.88 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: surfaceColor,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 20,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dot Indicator — frosted pill with animated dots
// ═══════════════════════════════════════════════════════════════════════════════

class _DotIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _DotIndicator({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? theme.primaryColor
                  : theme.disabledColor.withValues(alpha: isDark ? 0.5 : 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Price Display — price with discount styling
// ═══════════════════════════════════════════════════════════════════════════════

class _PriceDisplay extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final String? discountTag;

  const _PriceDisplay({
    required this.price,
    this.originalPrice,
    this.discountTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final hasDiscount = originalPrice != null && originalPrice! > price;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          AppCurrency.format(price, freeForZero: false),
          style: AppTextStyles.heading2.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        if (hasDiscount)
          Text(
            AppCurrency.format(originalPrice!, freeForZero: false),
            style: AppTextStyles.bodyLarge.copyWith(
              decoration: TextDecoration.lineThrough,
              color: onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        if (discountTag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              discountTag!,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Status Pill — colored badge for stock / delivery status
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Quantity Pill — modern inline quantity selector
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// Product Details Table — clean table-style key-value layout
// ═══════════════════════════════════════════════════════════════════════════════


class _ProductDetailsTable extends StatelessWidget {
  final String? shortDescription;
  final String? categoryLabel;
  final String? brand;
  final String? unitLabel;
  final bool? couponApplicable;
  final int? discountPercentage;
  final bool? inStock;
  final String? sku;
  final int? maxOrderQuantity;
  final int? minOrderQuantity;
  final String? estimatedDeliveryTime;
  final DateTime? expiryDate;
  final DateTime? manufacturingDate;
  final String? countryOfOrigin;
  final String? deliveryType;
  final int? deliveryCharge;
  final bool? freeDelivery;
  final String? weight;
  final String? attributes;
  final int? stockLeft;
  final bool outOfStock;
  final Color dividerColor;
  final Color onSurface;
  final Color successColor;
  final Color errorColor;

  const _ProductDetailsTable({
    this.shortDescription,
    this.categoryLabel,
    this.brand,
    this.unitLabel,
    this.couponApplicable,
    this.discountPercentage,
    this.inStock,
    this.sku,
    this.maxOrderQuantity,
    this.minOrderQuantity,
    this.estimatedDeliveryTime,
    this.expiryDate,
    this.manufacturingDate,
    this.countryOfOrigin,
    this.deliveryType,
    this.deliveryCharge,
    this.freeDelivery,
    this.weight,
    this.attributes,
    this.stockLeft,
    required this.outOfStock,
    required this.dividerColor,
    required this.onSurface,
    required this.successColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    final leftRows = <_TableEntry>[
      if ((brand ?? '').trim().isNotEmpty) _TableEntry('Brand', brand!.trim(), Icons.sell_outlined),
      if ((unitLabel ?? '').trim().isNotEmpty) _TableEntry('Unit', unitLabel!.trim(), Icons.inventory_2_outlined),
      if ((countryOfOrigin ?? '').trim().isNotEmpty) _TableEntry('Country of origin', countryOfOrigin!.trim(), Icons.language_outlined),
      if ((deliveryType ?? '').trim().isNotEmpty) _TableEntry('Delivery type', deliveryType!.trim(), Icons.local_shipping_outlined),
    ];
    
    final rightRows = <_TableEntry>[
      if ((estimatedDeliveryTime ?? '').trim().isNotEmpty) _TableEntry('Estimated delivery', estimatedDeliveryTime!.trim(), Icons.schedule_outlined),
      if (discountPercentage != null) _TableEntry('Discount', '$discountPercentage% off', Icons.percent_outlined),
      if (deliveryCharge != null) _TableEntry('Delivery charge', 'Rs $deliveryCharge', Icons.currency_rupee_outlined),
      if (maxOrderQuantity != null) _TableEntry('Max order', '$maxOrderQuantity', Icons.shopping_cart_checkout),
      if (minOrderQuantity != null) _TableEntry('Min order', '$minOrderQuantity', Icons.shopping_cart_checkout),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftRows.map((e) => _buildRow(e)).toList())),
        Container(width: 1, height: 150, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
        Expanded(child: Column(children: rightRows.map((e) => _buildRow(e)).toList())),
      ],
    );
  }

  Widget _buildRow(_TableEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, size: 16, color: const Color(0xFF388E3C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
            ),
          ),
          Text(
            entry.value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TableEntry {
  final String label;
  final String value;
  final IconData icon;

  const _TableEntry(this.label, this.value, this.icon);
}


class _FrostedBottomBar extends StatelessWidget {
  final bool enabled;
  final bool inCart;
  final int quantity;
  final bool canDecrement;
  final bool isLoading;
  final bool pulse;
  final Future<void> Function() onAddToCart;
  final Future<void> Function() onIncrement;
  final Future<void> Function() onDecrement;
  final VoidCallback onGoToCart;

  const _FrostedBottomBar({
    required this.enabled,
    required this.inCart,
    required this.quantity,
    required this.canDecrement,
    required this.isLoading,
    required this.pulse,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
    required this.onGoToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: inCart
                ? IntrinsicHeight(
                    child: Row(
                      children: [
                        // Quantity stepper — left
                        _BottomStepper(
                          quantity: quantity,
                          canDecrement: canDecrement,
                          onDecrement: () => onDecrement(),
                          onIncrement: () => onIncrement(),
                          theme: theme,
                        ),
                        const SizedBox(width: 12),
                        // Go to Cart button — right, same height as stepper
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: onGoToCart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: theme.colorScheme.onPrimary,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Go to Cart',
                                style: AppTextStyles.button.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : AnimatedScale(
                    scale: pulse ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: AppButton.primary(
                      text: 'Add to Cart',
                      isLoading: isLoading,
                      isFullWidth: true,
                      onPressed: enabled ? () => onAddToCart() : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bottom Stepper — quantity stepper inside the bottom bar
// ═══════════════════════════════════════════════════════════════════════════════

class _BottomStepper extends StatelessWidget {
  final int quantity;
  final bool canDecrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ThemeData theme;

  const _BottomStepper({
    required this.quantity,
    required this.canDecrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final border = theme.dividerColor.withValues(alpha: isDark ? 0.40 : 0.55);
    final onSurface = theme.colorScheme.onSurface;

    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canDecrement ? onDecrement : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.remove_rounded,
                    size: 18,
                    color: canDecrement
                        ? onSurface.withValues(alpha: 0.9)
                        : theme.disabledColor,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                quantity.toString(),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onIncrement,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
