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
import '../cart/cart_view.dart';
import '../home/home_widgets.dart';
import '../main/main_view.dart';
import '../product_listing/product_listing_view.dart';
import 'reviews_view.dart';
import 'widgets/review_display_widgets.dart';
import 'widgets/product_details_skeleton.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isUnsplashDemoUrl(String value) => value.contains('images.unsplash.com');

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = source.trim();
  if (value.isEmpty || _isUnsplashDemoUrl(value) || !_isHttpUrl(value)) {
    return const AssetImage(_fallbackImageAsset);
  }
  return NetworkImage(value);
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
          backgroundColor: theme.scaffoldBackgroundColor,
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
    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _imageSection()),
            SliverToBoxAdapter(child: _infoSection(theme)),
            if (_vm.similarProducts.isNotEmpty) ..._youMightAlsoLikeSlivers(),
            if (_vm.recommendedProducts.isNotEmpty) ..._recommendedSlivers(),
            if (_vm.categorySearchProducts.isNotEmpty)
              ..._categorySearchSlivers(),
            const SliverToBoxAdapter(child: SizedBox(height: 104)),
          ],
        ),
        _positionedBottomBar(theme, outOfStock),
      ],
    );
  }

  // ── Tablet two-column ────────────────────────────────────────────────────

  Widget _wideLayout(ThemeData theme, bool outOfStock) {
    final screenW = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: (screenW * 0.42).clamp(240.0, 480.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 104),
                physics: const BouncingScrollPhysics(),
                child: _imageSection(tabletMode: true),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _infoSection(theme, tabletMode: true),
                  ),
                  if (_vm.similarProducts.isNotEmpty)
                    ..._youMightAlsoLikeSlivers(),
                  if (_vm.recommendedProducts.isNotEmpty)
                    ..._recommendedSlivers(),
                  if (_vm.categorySearchProducts.isNotEmpty)
                    ..._categorySearchSlivers(),
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
                ],
              ),
            ),
          ],
        ),
        _positionedBottomBar(theme, outOfStock),
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

  Widget _infoSection(ThemeData theme, {bool tabletMode = false}) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.primaryColor;
    final discountColor = isDark ? AppColors.darkError : AppColors.lightError;
    final successColor = isDark
        ? AppColors.darkSuccess
        : AppColors.lightSuccess;
    // Highlight colour for "Only X left" — vibrant amber, distinct from yellow
    final lowStockColor = isDark
        ? AppColors.darkLowStock
        : AppColors.lightLowStock;

    final stockLeft = _vm.displayStockLeft;
    final outOfStock = stockLeft != null && stockLeft <= 0;
    final lowStock = stockLeft != null && stockLeft <= 5 && !outOfStock;
    final hPad = tabletMode ? 20.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category chip + Low Stock badge (inline) ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _vm.displayCategoryLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (lowStock) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lowStockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _firePulse,
                        child: Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 13,
                          color: lowStockColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Only $stockLeft left',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: lowStockColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── Product name ──
          Text(
            _vm.displayName,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          // ── Price section ──
          _PriceDisplay(
            price: _vm.displayPrice,
            originalPrice: _vm.displayOriginalPrice,
            discountTag: _vm.displayDiscountTag,
          ),

          const SizedBox(height: 16),

          // ── Status pills (out-of-stock only; Fast Delivery is on the image) ──
          if (outOfStock)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _StatusPill(
                icon: Icons.cancel_outlined,
                label: 'Out of Stock',
                color: discountColor,
                backgroundColor: discountColor.withValues(alpha: 0.1),
              ),
            ),

          const SizedBox(height: 20),

          if ((_vm.productDescription ?? '').isNotEmpty) ...[
            Text(
              'Description',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _vm.productDescription!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: onSurface.withValues(alpha: 0.72),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
          ],

          AppCard.action(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AllReviewsView(product: widget.product),
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ratings & Reviews',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Read customer feedback or write your own review.',
                        style: AppTextStyles.caption.copyWith(
                          color: onSurface.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),

          if (_vm.hasReviewData) ...[
            const SizedBox(height: 14),
            RatingSummaryCard(
              avgRating: _vm.reviewAverageRating ?? 0.0,
              totalRatings: _vm.reviewCount,
              reviewCount: _vm.reviewCount,
              distribution: _vm.reviewDistribution,
            ),
            if (_vm.topReviews.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Top Reviews',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < _vm.topReviews.length; i++) ...[
                ReviewDisplayCard(entry: _mapApiReview(_vm.topReviews[i])),
                if (i < _vm.topReviews.length - 1) const SizedBox(height: 10),
              ],
            ],
          ],

          const SizedBox(height: 14),

          // ── Expandable product details (table layout, expanded by default) ──
          if (_vm.hasProductDetailsTableData)
            AppCard.action(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _descExpanded = !_descExpanded);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Product Details',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _descExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _ProductDetailsTable(
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
                        estimatedDeliveryTime:
                            _vm.productEstimatedDeliveryTime,
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
                        errorColor: discountColor,
                      ),
                    ),
                    crossFadeState: _descExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeOut,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
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
                category: widget.product.category,
                currentBottomBarIndex: widget.currentBottomBarIndex,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section sliver groups ─────────────────────────────────────────────────

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
            final allCats = ProductCategory.values;
            final nextCat =
                allCats[(widget.product.category.index + 1) % allCats.length];
            Navigator.of(context).push(
              ProductListingView.route(
                category: nextCat,
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
                category: widget.product.category,
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
    this.aspectRatio = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final discountBase = isDark ? AppColors.darkError : AppColors.lightError;
    final urls = imageUrls.isEmpty ? const <String>[] : imageUrls;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(
                  alpha: isDark ? 0.25 : 0.10,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fallback background
                ColoredBox(color: theme.colorScheme.surfaceContainerHighest),

                // Image carousel
                if (urls.isNotEmpty)
                  PageView.builder(
                    controller: pageController,
                    itemCount: urls.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (_, index) {
                      final url = urls[index];
                      return GestureDetector(
                        onTap: () => onZoomTap(url),
                        child: Hero(
                          tag: 'product_image_$url',
                          child: Image(
                            image: _resolveImageProvider(url),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: theme.disabledColor,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Bottom gradient for overlay readability
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating overlays
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Top: discount badge + action column ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (discountTag != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: discountBase,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                discountTag!,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Column(
                            children: [
                              _ActionCircle(
                                icon: Icons.share_outlined,
                                onTap: onShareTap,
                                pulse: sharePulse,
                                surfaceColor: theme.colorScheme.surface
                                    .withValues(alpha: 0.88),
                                iconColor: onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 8),
                              _ActionCircle(
                                icon: isWishlisted
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                onTap: onWishlistTap,
                                pulse: wishlistPulse,
                                surfaceColor: theme.colorScheme.surface
                                    .withValues(alpha: 0.88),
                                iconColor: isWishlisted
                                    ? discountBase
                                    : onSurface.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // ── Bottom: dots ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Spacer(),
                          if (urls.length > 1)
                            _DotIndicator(
                              count: urls.length,
                              activeIndex: activeIndex,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Action Circle — floating circle action button (share, wishlist)
// ═══════════════════════════════════════════════════════════════════════════════

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
    final rows = <_TableEntry>[
      if ((shortDescription ?? '').trim().isNotEmpty)
        _TableEntry('Short description', shortDescription!.trim()),
      if ((categoryLabel ?? '').trim().isNotEmpty)
        _TableEntry('Category', categoryLabel!.trim()),
      if ((brand ?? '').trim().isNotEmpty)
        _TableEntry('Brand', brand!.trim()),
      if ((unitLabel ?? '').trim().isNotEmpty)
        _TableEntry('Unit', unitLabel!.trim()),
      if (couponApplicable != null)
        _TableEntry(
          'Coupon',
          couponApplicable == true ? 'Applicable' : 'Not applicable',
        ),
      if (discountPercentage != null)
        _TableEntry('Discount', '$discountPercentage%'),
      if (inStock != null)
        _TableEntry('In stock', inStock == true ? 'Yes' : 'No'),
      if ((sku ?? '').trim().isNotEmpty) _TableEntry('SKU', sku!.trim()),
      if (maxOrderQuantity != null)
        _TableEntry('Max order quantity', '$maxOrderQuantity'),
      if (minOrderQuantity != null)
        _TableEntry('Min order quantity', '$minOrderQuantity'),
      if ((estimatedDeliveryTime ?? '').trim().isNotEmpty)
        _TableEntry(
          'Estimated delivery',
          estimatedDeliveryTime!.trim(),
        ),
      if (expiryDate != null)
        _TableEntry('Expiry date', _formatDate(expiryDate!)),
      if (manufacturingDate != null)
        _TableEntry('Manufactured on', _formatDate(manufacturingDate!)),
      if ((countryOfOrigin ?? '').trim().isNotEmpty)
        _TableEntry('Country of origin', countryOfOrigin!.trim()),
      if ((deliveryType ?? '').trim().isNotEmpty)
        _TableEntry('Delivery type', deliveryType!.trim()),
      if (deliveryCharge != null)
        _TableEntry('Delivery charge', 'Rs $deliveryCharge'),
      if (freeDelivery != null)
        _TableEntry('Free delivery', freeDelivery == true ? 'Yes' : 'No'),
      if ((weight ?? '').trim().isNotEmpty)
        _TableEntry('Weight', weight!.trim()),
      if ((attributes ?? '').trim().isNotEmpty)
        _TableEntry('Attributes', attributes!.trim()),
      if (stockLeft != null)
        _TableEntry(
          'Availability',
          outOfStock ? 'Out of stock' : '$stockLeft units available',
          valueColor: outOfStock ? errorColor : successColor,
        ),
    ];

    return Column(
      children: List.generate(rows.length, (i) {
        final entry = rows[i];
        final isLast = i == rows.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      entry.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: entry.valueColor ?? onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                thickness: 0.7,
                color: dividerColor.withValues(alpha: 0.4),
              ),
          ],
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    const monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _TableEntry {
  final String label;
  final String value;
  final Color? valueColor;

  const _TableEntry(this.label, this.value, {this.valueColor});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Frosted Bottom Bar — frosted glass CTA bar
// ═══════════════════════════════════════════════════════════════════════════════

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
