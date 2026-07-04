import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_currency.dart';
import '../../core/auth/auth_guard.dart';
import '../../common/cards/product_grid_card.dart';
import '../../common/drawer/app_drawer.dart';
import '../../common/appbar/primary_sliver_app_bar.dart';
import '../../common/buttons/app_button.dart';
import '../../common/snackbars/app_snackbar.dart';
import '../../core/cart/cart_coordinator.dart';
import '../../core/product_listing/product_listing_coordinator.dart';
import '../../core/wishlist/wishlist_coordinator.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/wishlist_item_model.dart';
import '../../services/api_service.dart';
import '../home/home_widgets.dart';
import '../main/main_view.dart';
import '../product_details/product_details_view.dart';

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
    return NetworkImage(value);
  }
  return const AssetImage(_fallbackImageAsset);
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

class WishlistItem {
  final String id;
  final String imageUrl;
  final String title;
  final String sku;
  final double price;
  final double originalPrice;
  final String discountTag;
  final double rating;
  final int reviewCount;
  bool isAddedToCart;

  WishlistItem({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.sku,
    required this.price,
    required this.originalPrice,
    required this.discountTag,
    required this.rating,
    required this.reviewCount,
    this.isAddedToCart = false,
  });

  double get discountPercent =>
      ((originalPrice - price) / originalPrice * 100).roundToDouble();
}

// ─────────────────────────────────────────────
//  MAIN VIEW
// ─────────────────────────────────────────────

class WishlistView extends StatefulWidget {
  const WishlistView({super.key});

  @override
  State<WishlistView> createState() => _WishlistViewState();
}

class _WishlistViewState extends State<WishlistView>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  String? _profilePicUrl;

  StreamSubscription<List<WishlistItemModel>>? _sub;

  late AnimationController _emptyCtrl;
  late Animation<double> _floatAnimation;

  List<WishlistItem> _wishlistItems = [];

  List<ProductModel> get _recommendedItems => _wishlistItems
      .map(
        (item) => ProductModel(
          id: item.id,
          category: ProductCategory.grocery,
          name: item.title,
          imageUrl: item.imageUrl,
          price: item.price,
          originalPrice: item.originalPrice > item.price
              ? item.originalPrice
              : null,
          discountTag: item.discountTag.trim().isNotEmpty
              ? item.discountTag
              : null,
          rating: item.rating > 0 ? item.rating : null,
          reviewCount: item.reviewCount > 0 ? item.reviewCount : null,
        ),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _bindWishlist();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final allowed = await handleProtectedAction(context);
      if (!allowed) return;
      final result = await WishlistCoordinator.instance.syncFromServer();
      if (!mounted) return;
      if (!result.success && result.message.trim().isNotEmpty) {
        AppSnackbar.warning(context, result.message);
      }
    });

    _emptyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _emptyCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _emptyCtrl.dispose();
    super.dispose();
  }

  void _bindWishlist() {
    WishlistCoordinator.instance.init();
    _sub?.cancel();
    _sub = WishlistCoordinator.instance.watchItems().listen((items) {
      if (!mounted) return;
      setState(() {
        _wishlistItems = items
            .map(
              (e) => WishlistItem(
                id: e.productId,
                imageUrl: _apiService.resolveImageUrl(e.imageUrl),
                title: e.name,
                sku: (e.sku ?? '').trim(),
                price: e.unitPrice,
                originalPrice: e.unitPrice,
                discountTag: '',
                rating: 0,
                reviewCount: 0,
              ),
            )
            .toList(growable: false);
      });
    });
  }

  double get _totalSavings => _wishlistItems.fold(
    0,
    (sum, item) => sum + (item.originalPrice - item.price),
  );

  double get _totalWishlistValue =>
      _wishlistItems.fold(0, (sum, item) => sum + item.price);

  Future<void> _removeItem(WishlistItem item) async {
    final allowed = await handleProtectedAction(context);
    if (!allowed) return;

    HapticFeedback.heavyImpact();
    final result = await WishlistCoordinator.instance.removeItem(item.id);
    if (!mounted) return;
    if (result.success) {
      AppSnackbar.success(context, result.message);
    } else {
      AppSnackbar.warning(context, result.message);
    }
  }

  Future<void> _addToCart(WishlistItem item) async {
    final allowed = await handleProtectedAction(context);
    if (!allowed) return;

    HapticFeedback.heavyImpact();
    await CartCoordinator.instance.addItem(
      CartItemModel(
        productId: item.id,
        name: item.title,
        imageUrl: item.imageUrl,
        unitPrice: item.price,
        quantity: 1,
      ),
    );
    setState(() => item.isAddedToCart = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => item.isAddedToCart = false);
    });
  }

  Future<void> _addAllToCart() async {
    final allowed = await handleProtectedAction(context);
    if (!allowed) return;

    HapticFeedback.heavyImpact();
    for (final item in _wishlistItems) {
      await CartCoordinator.instance.addItem(
        CartItemModel(
          productId: item.id,
          name: item.title,
          imageUrl: item.imageUrl,
          unitPrice: item.price,
          quantity: 1,
        ),
      );
    }
    setState(() {
      for (final item in _wishlistItems) {
        item.isAddedToCart = true;
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        for (final item in _wishlistItems) {
          item.isAddedToCart = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = _wishlistItems.isEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(
        profilePicUrl: _profilePicUrl,
        currentBottomBarIndex: 1,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.normal,
        ),
        slivers: [
          // ── App Bar ─────────────────────────────
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
            onSearchChanged: (val) => debugPrint('Searching: $val'),
            currentBottomBarIndex: 1,
          ),

          if (!isEmpty) ...[
            // ── Savings Banner ───────────────────
            SliverToBoxAdapter(
              child: _SavingsBanner(
                itemCount: _wishlistItems.length,
                totalSavings: _totalSavings,
                totalValue: _totalWishlistValue,
                onAddAll: _addAllToCart,
              ),
            ),

            // ── Wishlist Cards ───────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _wishlistItems[index];
                  return _AnimatedWishlistCard(
                    key: ValueKey(item.id),
                    item: item,
                    index: index,
                    onTap: () => _openProductDetails(item),
                    onRemove: () => _removeItem(item),
                    onAddToCart: () => _addToCart(item),
                  );
                }, childCount: _wishlistItems.length),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ] else ...[
            // ── Empty State ───────────────────────
            SliverToBoxAdapter(
              child: _EmptyWishlistState(floatAnimation: _floatAnimation),
            ),
          ],

          if (_recommendedItems.isNotEmpty) ...[
            // ── Recommended Section ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: EcommerceSectionTitle(
                  title: !isEmpty ? 'Similar Items' : 'Recommended for you',
                  actionText: 'See All',
                  onActionTap: () {
                    ProductListingCoordinator.instance.openListing(
                      context,
                      category: ProductCategory.grocery,
                      currentBottomBarIndex: 1,
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.sizeOf(context).width;
                  final cardWidth = ((screenWidth - 32 - 12) / 2)
                      .clamp(150.0, 220.0)
                      .toDouble();
                  final cardHeight = cardWidth / 0.58;

                  return SizedBox(
                    height: cardHeight,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _recommendedItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final product = _recommendedItems[index];
                        return SizedBox(
                          width: cardWidth,
                          child: ProductGridCard(
                            key: ValueKey(product.id),
                            product: product,
                            onTap: () {
                              Navigator.of(context).push(
                                ProductDetailsView.route(
                                  product: product,
                                  currentBottomBarIndex: 1,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  void _openProductDetails(WishlistItem item) {
    Navigator.of(context).push(
      ProductDetailsView.route(
        product: ProductModel(
          id: item.id,
          category: ProductCategory.grocery,
          name: item.title,
          imageUrl: item.imageUrl,
          price: item.price,
          originalPrice: item.originalPrice > item.price
              ? item.originalPrice
              : null,
          discountTag: item.discountTag.trim().isNotEmpty
              ? item.discountTag
              : null,
          rating: item.rating > 0 ? item.rating : null,
          reviewCount: item.reviewCount > 0 ? item.reviewCount : null,
        ),
        currentBottomBarIndex: 1,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SAVINGS BANNER
// ─────────────────────────────────────────────

class _SavingsBanner extends StatelessWidget {
  final int itemCount;
  final double totalSavings;
  final double totalValue;
  final VoidCallback onAddAll;

  const _SavingsBanner({
    required this.itemCount,
    required this.totalSavings,
    required this.totalValue,
    required this.onAddAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$itemCount saved item${itemCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'You\'re saving ${AppCurrency.symbol}${totalSavings.toStringAsFixed(2)} on this list!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'List Total',
                  value:
                      '${AppCurrency.symbol}${totalValue.toStringAsFixed(2)}',
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.25),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'You Save',
                  value:
                      '${AppCurrency.symbol}${totalSavings.toStringAsFixed(2)}',
                  valueColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSuccess
                      : AppColors.teaGreenSoft,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAddAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 15,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add All',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _BannerStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED WISHLIST CARD
// ─────────────────────────────────────────────

class _AnimatedWishlistCard extends StatefulWidget {
  final WishlistItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const _AnimatedWishlistCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onRemove,
    required this.onAddToCart,
  });

  @override
  State<_AnimatedWishlistCard> createState() => _AnimatedWishlistCardState();
}

class _AnimatedWishlistCardState extends State<_AnimatedWishlistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380 + widget.index * 70),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 90), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: _WishlistCard(
              item: widget.item,
              onRemove: widget.onRemove,
              onAddToCart: widget.onAddToCart,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WISHLIST CARD
// ─────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const _WishlistCard({
    required this.item,
    required this.onRemove,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDiscount = item.discountTag.trim().isNotEmpty;
    final hasRating = item.reviewCount > 0 && item.rating > 0;
    final showOriginalPrice = item.originalPrice > item.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ─────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image(
                    image: _resolveImageProvider(item.imageUrl),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkError
                            : AppColors.lightError,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        item.discountTag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Info ──────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.sku.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${item.sku}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),

                  if (hasRating) ...[
                    // Star rating
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final filled = i < item.rating.floor();
                          final half =
                              !filled &&
                              i < item.rating &&
                              (item.rating - i) >= 0.5;
                          return Icon(
                            filled
                                ? Icons.star_rounded
                                : half
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                            size: 13,
                            color: isDark
                                ? AppColors.darkWarning
                                : AppColors.lightWarning,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          '${item.rating} (${item.reviewCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${AppCurrency.symbol}${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (showOriginalPrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${AppCurrency.symbol}${item.originalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.38,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions ───────────────────────
            Column(
              children: [
                // Remove button
                _IconActionButton(
                  icon: Icons.favorite,
                  color: isDark ? AppColors.darkError : AppColors.lightError,
                  backgroundColor:
                      (isDark ? AppColors.darkError : AppColors.lightError)
                          .withValues(alpha: 0.1),
                  onTap: onRemove,
                  tooltip: 'Remove',
                ),
                const SizedBox(height: 8),
                // Add to cart button
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: item.isAddedToCart
                      ? _IconActionButton(
                          key: const ValueKey('added'),
                          icon: Icons.check_rounded,
                          color: isDark
                              ? AppColors.darkSuccess
                              : AppColors.lightSuccess,
                          backgroundColor:
                              (isDark
                                      ? AppColors.darkSuccess
                                      : AppColors.lightSuccess)
                                  .withValues(alpha: 0.12),
                          onTap: () {},
                          tooltip: 'Added!',
                        )
                      : _IconActionButton(
                          key: const ValueKey('cart'),
                          icon: Icons.shopping_cart_outlined,
                          color: theme.primaryColor,
                          backgroundColor: theme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          onTap: onAddToCart,
                          tooltip: 'Add to cart',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ICON ACTION BUTTON
// ─────────────────────────────────────────────

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;
  final String tooltip;

  const _IconActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyWishlistState extends StatelessWidget {
  final Animation<double> floatAnimation;
  const _EmptyWishlistState({required this.floatAnimation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 8),
      child: Column(
        children: [
          // Floating icon with animated translate
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, floatAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 42,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Nothing saved yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the ♡ on any product to save it here.\nYour favourites are always one tap away.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          AppButton.primary(
            text: 'Discover Products',
            icon: Icons.storefront_rounded,
            isFullWidth: true,
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainView(initialIndex: 0),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
