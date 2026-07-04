import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/appbar/common_app_bar.dart';
import '../../common/buttons/app_button.dart';
import '../../common/bottombar/common_bottom_bar.dart';
import '../../common/cards/app_card.dart';
import '../../common/cards/product_grid_card.dart';
import '../../common/dialogs/app_dialog.dart';
import '../../common/pages/no_internet_page.dart';
import '../../core/auth/auth_guard.dart';
import '../../core/cart/cart_coordinator.dart';
import '../../core/cart/cart_pricing.dart';
import '../../core/location/address_location_coordinator.dart';
import '../../core/product_listing/product_listing_coordinator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../core/wishlist/wishlist_coordinator.dart';
import '../../data/models/address_models.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/wishlist_item_model.dart';
import '../../models/product_list_model.dart';
import '../../services/api_service.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../addresses/manual_address_form_view.dart';
import '../checkout/checkout_view.dart';
import '../home/home_widgets.dart';
import '../main/main_view.dart';
import '../product_details/product_details_view.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = ApiService().resolveImageUrl(source).trim();
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


class CartView extends StatefulWidget {
  final int currentBottomBarIndex;

  const CartView({super.key, this.currentBottomBarIndex = 0});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late final CartViewModel _vm;
  late final AnimationController _emptyStateController;
  late final Animation<double> _floatAnimation;

  AddressCache? _addressCache;
  bool _addressLoading = true;
  bool _recommendedLoading = true;
  int _retryCount = 0;

  List<ProductModel> _recommendedItems = const <ProductModel>[];

  @override
  void initState() {
    super.initState();
    _vm = CartViewModel();
    _vm.init();
    _loadAddressCache();
    _loadRecommendedProducts();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final allowed = await handleProtectedAction(context);
      if (!allowed) return;
      await CartCoordinator.instance.syncFromServer();
    });

    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _emptyStateController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _loadAddressCache() async {
    if (!mounted) return;
    setState(() => _addressLoading = true);
    try {
      final cache = await AddressLocationCoordinator.instance.getCache();
      if (!mounted) return;
      setState(() {
        _addressCache = cache;
        _addressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _addressLoading = false);
    }
  }

  Future<void> _loadRecommendedProducts() async {
    if (!mounted) return;
    setState(() => _recommendedLoading = true);

    try {
      final response = await _apiService.getProducts();
      final items = (response.data ?? const <Data>[])
          .where((p) => p.id != null && (p.name ?? '').trim().isNotEmpty)
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) => _mapApiProduct(entry.value, entry.key))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _recommendedItems = items.take(10).toList(growable: false);
        _recommendedLoading = false;
      });
    } catch (e) {
      debugPrint('[CartView] Failed to load recommended products: $e');
      if (!mounted) return;
      setState(() {
        _recommendedItems = const <ProductModel>[];
        _recommendedLoading = false;
      });
    }
  }

  ProductModel _mapApiProduct(Data item, int index) {
    final id = item.id?.toString() ?? 'cart-api-$index';
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

  Future<void> _openManualAddressForm({ManualAddress? existing}) async {
    HapticFeedback.selectionClick();
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ManualAddressFormView(
          currentBottomBarIndex: widget.currentBottomBarIndex,
          existing: existing,
        ),
      ),
    );

    if (!mounted) return;
    if (saved == true) {
      await _loadAddressCache();
    }
  }

  void _retryLoad() {
    setState(() => _retryCount++);
    _vm.init();
  }

  String _addressTitle(AddressCache cache) {
    if (cache.isAutoSelected) return 'Current Location';
    return cache.selectedManual?.label ?? 'Delivery Address';
  }

  String _addressSubtitle(AddressCache cache) {
    if (cache.isAutoSelected) {
      final auto = cache.autoLocation;
      return auto?.formattedAddress ??
          (auto != null
              ? '${auto.latitude.toStringAsFixed(6)}, ${auto.longitude.toStringAsFixed(6)}'
              : 'Not detected yet');
    }
    return cache.selectedManual?.formatted ?? '';
  }

  Future<void> _openAddressPicker() async {
    final cache =
        _addressCache ?? await AddressLocationCoordinator.instance.getCache();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;

        Widget buildTile({
          required String id,
          required String title,
          required String subtitle,
          bool enabled = true,
        }) {
          final selected = cache.selectedAddressId == id;
          return RadioListTile<String>(
            value: id,
            groupValue: cache.selectedAddressId,
            onChanged: enabled
                ? (v) async {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx);
                    await AddressLocationCoordinator.instance
                        .setSelectedAddressId(
                          v ?? AddressRepositoryKeys.autoId,
                        );
                    if (!mounted) return;
                    await _loadAddressCache();
                  }
                : null,
            title: Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: enabled ? onSurface : onSurface.withValues(alpha: 0.5),
              ),
            ),
            subtitle: Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: enabled
                    ? onSurface.withValues(alpha: 0.7)
                    : onSurface.withValues(alpha: 0.45),
              ),
            ),
            controlAffinity: ListTileControlAffinity.trailing,
            selected: selected,
          );
        }

        final auto = cache.autoLocation;
        final autoSubtitle =
            auto?.formattedAddress ??
            (auto != null
                ? '${auto.latitude.toStringAsFixed(6)}, ${auto.longitude.toStringAsFixed(6)}'
                : 'Not detected yet');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select delivery address',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                buildTile(
                  id: AddressRepositoryKeys.autoId,
                  title: 'Current Location',
                  subtitle: autoSubtitle,
                  enabled: true,
                ),
                if (cache.manualAddresses.isNotEmpty) const Divider(height: 1),
                for (final m in cache.manualAddresses)
                  buildTile(id: m.id, title: m.label, subtitle: m.formatted),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _openManualAddressForm();
                      },
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Add Address Manually'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: CommonAppBar(title: 'Cart'),
          bottomNavigationBar: CommonBottomBar(
            currentIndex: widget.currentBottomBarIndex,
            onTap: (index) {
              if (index == widget.currentBottomBarIndex) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainView(initialIndex: index),
                  ),
                  (route) => false,
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
          body: SafeArea(
            child: _vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vm.hasError
                ? _vm.isNetworkError
                      ? NoInternetPage(
                          retryCount: _retryCount,
                          onRetry: _retryLoad,
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Center(
                            child: Text(
                              _vm.errorMessage ?? 'Something went wrong.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: onSurface.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                : _vm.isEmpty
                ? ListView(
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    children: [
                      _EmptyCartState(
                        floatAnimation: _floatAnimation,
                        onStartShopping: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainView(initialIndex: 0),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      if (_recommendedLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      if (_recommendedItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        EcommerceSectionTitle(
                          title: 'Recommended for you',
                          actionText: 'See All',
                          onActionTap: () {
                            ProductListingCoordinator.instance.openListing(
                              context,
                              category: ProductCategory.grocery,
                              currentBottomBarIndex:
                                  widget.currentBottomBarIndex,
                            );
                          },
                        ),
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.sizeOf(
                              context,
                            ).width;
                            final cardWidth = ((screenWidth - 32 - 12) / 2)
                                .clamp(150.0, 220.0)
                                .toDouble();
                            final cardHeight = cardWidth / 0.58;

                            return SizedBox(
                              height: cardHeight,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(
                                  decelerationRate:
                                      ScrollDecelerationRate.normal,
                                ),
                                itemCount: _recommendedItems.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
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
                                            currentBottomBarIndex:
                                                widget.currentBottomBarIndex,
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
                      ],
                      const SizedBox(height: 24),
                    ],
                  )
                : StreamBuilder<List<WishlistItemModel>>(
                    stream: WishlistCoordinator.instance.watchItems(),
                    builder: (context, snapshot) {
                      final wishlistedIds =
                          (snapshot.data ?? const <WishlistItemModel>[])
                              .map((e) => e.productId)
                              .toSet();

                      final itemsLen = _vm.items.length;
                      final listChildCount = itemsLen == 0
                          ? 0
                          : (itemsLen * 2) - 1;

                      final cache = _addressCache;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          decelerationRate: ScrollDecelerationRate.fast,
                        ),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                if (index.isOdd) {
                                  return const SizedBox(height: 12);
                                }

                                final itemIndex = index ~/ 2;
                                final item = _vm.items[itemIndex];
                                return _CartItemCard(
                                  item: item,
                                  isWishlisted: wishlistedIds.contains(
                                    item.productId,
                                  ),
                                  onIncrement: () =>
                                      _vm.increment(item.productId),
                                  onDecrement: () =>
                                      _vm.decrement(item.productId),
                                  onMoveToWishlist: () async {
                                    HapticFeedback.lightImpact();
                                    await WishlistCoordinator.instance.addItem(
                                      WishlistItemModel(
                                        productId: item.productId,
                                        name: item.name,
                                        imageUrl: item.imageUrl,
                                        unitPrice: item.unitPrice,
                                      ),
                                    );
                                  },
                                  onRemove: () async {
                                    await CartCoordinator.instance.removeItem(
                                      item.productId,
                                    );
                                    if (!context.mounted) return;
                                  },
                                );
                              }, childCount: listChildCount),
                            ),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _CartAddressCard(
                                    loading: _addressLoading,
                                    title: cache == null
                                        ? 'Delivery Address'
                                        : _addressTitle(cache),
                                    subtitle: cache == null
                                        ? 'Select an address for delivery'
                                        : _addressSubtitle(cache),
                                    onTap: _openAddressPicker,
                                  ),
                                  const SizedBox(height: 12),
                                  _CartSummaryCard(
                                    subtotal: _vm.subtotal,
                                    delivery: _vm.deliveryCharge,
                                    handling: _vm.handlingCharge,
                                    smallOrderSurcharge:
                                        _vm.smallOrderSurcharge,
                                    total: _vm.totalAmount,
                                    onInfoTap: () {
                                      HapticFeedback.selectionClick();
                                      final s = AppCurrency.symbol;
                                      final deliveryCharge = CartPricing
                                          .deliveryChargeAmount
                                          .toStringAsFixed(0);

                                      AppDialog.showAlert(
                                        context: context,
                                        title: 'Delivery & Fees',
                                        message:
                                            'Pricing rules:\n\n'
                                            '• Flat $s$deliveryCharge delivery charge on all orders.',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _vm.items.isEmpty
                                          ? null
                                          : () async {
                                              HapticFeedback.selectionClick();
                                              await CartCoordinator.instance
                                                  .clear();
                                            },
                                      icon: const Icon(
                                        Icons.delete_sweep_outlined,
                                      ),
                                      label: const Text('Clear Cart'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppButton.primary(
                                    text: 'Proceed to Checkout',
                                    isFullWidth: true,
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CheckoutView(
                                            currentBottomBarIndex:
                                                widget.currentBottomBarIndex,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  final Animation<double> floatAnimation;
  final VoidCallback onStartShopping;

  const _EmptyCartState({
    required this.floatAnimation,
    required this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                        Icons.shopping_cart_outlined,
                        size: 42,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Your cart is empty',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading2.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add items from product pages or your wishlist, and they’ll show up here for checkout.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              AppButton.primary(
                text: 'Start Shopping',
                icon: Icons.storefront_rounded,
                isFullWidth: true,
                onPressed: onStartShopping,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItemModel item;
  final bool isWishlisted;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onMoveToWishlist;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.isWishlisted,
    required this.onIncrement,
    required this.onDecrement,
    required this.onMoveToWishlist,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.primaryColor;
    final wishlistedColor = theme.brightness == Brightness.dark
        ? AppColors.darkError
        : AppColors.lightError;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: theme.dividerColor.withValues(alpha: 0.2),
              child: _ProductImage(imageUrl: item.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: isWishlisted
                              ? 'In wishlist'
                              : 'Add to wishlist',
                          child: InkWell(
                            onTap: onMoveToWishlist,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: isWishlisted
                                    ? wishlistedColor
                                    : onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Remove',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onRemove();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppCurrency.symbol}${item.unitPrice.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: item.quantity <= 1
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onDecrement();
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onIncrement();
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${AppCurrency.symbol}${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Material(
      color: theme.primaryColor.withValues(alpha: enabled ? 0.10 : 0.05),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? theme.primaryColor
                  : theme.primaryColor.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.trim().isEmpty) {
      return Image.asset(_fallbackImageAsset, fit: BoxFit.cover);
    }

    return Image(
      image: _resolveImageProvider(url),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(_fallbackImageAsset, fit: BoxFit.cover);
      },
    );
  }
}

class _CartAddressCard extends StatelessWidget {
  final bool loading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CartAddressCard({
    required this.loading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Address',
                    style: AppTextStyles.caption.copyWith(
                      color: onSurface.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (loading)
                    Text(
                      'Loading address…',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else ...[
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              size: 22,
              color: onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummaryCard extends StatefulWidget {
  final double subtotal;
  final double delivery;
  final double handling;
  final double smallOrderSurcharge;
  final double total;
  final VoidCallback onInfoTap;

  const _CartSummaryCard({
    required this.subtotal,
    required this.delivery,
    required this.handling,
    required this.smallOrderSurcharge,
    required this.total,
    required this.onInfoTap,
  });

  @override
  State<_CartSummaryCard> createState() => _CartSummaryCardState();
}

class _CartSummaryCardState extends State<_CartSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final subtotal = widget.subtotal;
    final delivery = widget.delivery;
    final handling = widget.handling;
    final smallOrderSurcharge = widget.smallOrderSurcharge;
    final total = widget.total;

    TextStyle rowStyle({bool bold = false, Color? color}) {
      return AppTextStyles.bodyMedium.copyWith(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color ?? onSurface,
      );
    }

    Widget row(String label, String value, {bool bold = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: rowStyle(
                  bold: bold,
                  color: onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
            Text(
              value,
              style: rowStyle(bold: bold, color: color),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Summary',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Tooltip(
                message: _expanded ? 'Collapse' : 'Expand',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Pricing rules',
                child: InkWell(
                  onTap: widget.onInfoTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_expanded) ...[
            row(
              'Subtotal',
              '${AppCurrency.symbol}${subtotal.toStringAsFixed(2)}',
            ),
            row(
              'Delivery Charge',
              delivery <= 0
                  ? 'FREE'
                  : '${AppCurrency.symbol}${delivery.toStringAsFixed(2)}',
              color: delivery <= 0 ? theme.primaryColor : null,
            ),
            if (smallOrderSurcharge > 0)
              row(
                'Small-order Charge',
                '${AppCurrency.symbol}${smallOrderSurcharge.toStringAsFixed(2)}',
              ),
            if (handling > 0)
              row(
                'Handling Charge',
                '${AppCurrency.symbol}${handling.toStringAsFixed(2)}',
              ),
            Divider(color: theme.dividerColor.withValues(alpha: 0.8)),
          ],
          row(
            'Total Amount',
            '${AppCurrency.symbol}${total.toStringAsFixed(2)}',
            bold: true,
            color: theme.primaryColor,
          ),
        ],
      ),
    );
  }
}
