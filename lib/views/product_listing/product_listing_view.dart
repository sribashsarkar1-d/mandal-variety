import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/bottombar/common_bottom_bar.dart';
import '../../common/cards/product_grid_card.dart';
import '../../common/buttons/cart_icon_button.dart';
import '../../common/searchbar/app_search_bar.dart';
import '../../common/pages/no_internet_page.dart';
import '../../core/cart/cart_coordinator.dart';
import '../../core/cart/cart_pricing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../core/utils/platform_helper.dart';
import '../../core/tobacco/tobacco_keyword_matcher.dart';
import '../../core/tobacco/tobacco_search_redirector.dart';
import '../../data/models/product_model.dart';
import '../../viewmodels/product_listing_viewmodel.dart';
import '../main/main_view.dart';
import '../product_details/product_details_view.dart';
import 'widgets/product_listing_skeleton.dart';

class ProductListingView extends StatefulWidget {
  final ProductCategory category;
  final int currentBottomBarIndex;
  final String? initialSearchQuery;

  const ProductListingView({
    super.key,
    required this.category,
    this.currentBottomBarIndex = 0,
    this.initialSearchQuery,
  });

  static Route<void> route({
    required ProductCategory category,
    int currentBottomBarIndex = 0,
    String? initialSearchQuery,
  }) {
    Widget builder(BuildContext _) => ProductListingView(
      category: category,
      currentBottomBarIndex: currentBottomBarIndex,
      initialSearchQuery: initialSearchQuery,
    );

    return PlatformHelper.isIOS
        ? CupertinoPageRoute<void>(builder: builder)
        : MaterialPageRoute<void>(builder: builder);
  }

  @override
  State<ProductListingView> createState() => _ProductListingViewState();
}

class _ProductListingViewState extends State<ProductListingView> {
  late final ProductListingViewModel _vm;
  late final ScrollController _scrollController;

  // Skeleton stays visible for a minimum of 1.8 s (static timing).
  // Switch to API loading duration once live network calls are in place.
  bool _skeletonVisible = true;
  Timer? _skeletonTimer;
  int _retryCount = 0;

  bool get _canPop => ModalRoute.of(context)?.canPop ?? false;

  @override
  void initState() {
    super.initState();
    _vm = ProductListingViewModel(category: widget.category);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    final initial = widget.initialSearchQuery;
    if (initial != null && initial.trim().isNotEmpty) {
      _vm.setSearchQuery(initial);
    }

    _vm.load();

    // Enforce minimum skeleton visibility so the shimmer is readable
    _skeletonTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _skeletonVisible = false);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasPixels) return;
    if (position.pixels >= position.maxScrollExtent - 520) {
      _vm.loadMore();
    }
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openSortPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final textPrimary = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        Widget buildTile(ProductSort sort) {
          final selected = _vm.sort == sort;

          return RadioListTile<ProductSort>(
            value: sort,
            groupValue: _vm.sort,
            onChanged: (v) {
              if (v == null) return;
              HapticFeedback.selectionClick();
              Navigator.pop(ctx);
              _vm.setSort(v);
            },
            title: Text(
              sort.label,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.trailing,
            selected: selected,
          );
        }

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sheetHeight = (constraints.maxHeight * 0.75)
                  .clamp(0.0, 420.0)
                  .toDouble();

              return SizedBox(
                height: sheetHeight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                        child: Text(
                          'Sort by',
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(
                            decelerationRate: ScrollDecelerationRate.normal,
                          ),
                          children: [
                            for (final s in ProductSort.values) buildTile(s),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.primaryColor;

    final headerBg = theme.scaffoldBackgroundColor.withValues(alpha: 0.98);
    final topInset = MediaQuery.paddingOf(context).top;

    final searchBar = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppSearchBar(
        hintText: 'Search ${widget.category.searchHint}...',
        staticPrefix: 'Search ',
        initialText: widget.initialSearchQuery,
        onChanged: (q) {
          if (widget.category != ProductCategory.tobacco &&
              TobaccoKeywordMatcher.isTobaccoQuery(q)) {
            TobaccoSearchRedirector.maybeRedirect(
              context,
              q,
              currentBottomBarIndex: widget.currentBottomBarIndex,
            );
            return;
          }
          _vm.setSearchQuery(q);
        },
        onSubmitted: (q) {
          if (widget.category != ProductCategory.tobacco &&
              TobaccoKeywordMatcher.isTobaccoQuery(q)) {
            TobaccoSearchRedirector.maybeRedirect(
              context,
              q,
              currentBottomBarIndex: widget.currentBottomBarIndex,
            );
            return;
          }
          _vm.setSearchQuery(q);
        },
      ),
    );

    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          extendBody: false,
          backgroundColor: theme.scaffoldBackgroundColor,
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
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.normal,
                ),
                slivers: [
                  // ── Compact header (search + chips + sort) ──────────────
                  SliverAppBar(
                    backgroundColor: headerBg,
                    elevation: 0,
                    floating: true,
                    snap: true,
                    pinned: false,
                    primary: false,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 0,
                    collapsedHeight: topInset + 100,
                    expandedHeight: topInset + 100,
                    flexibleSpace: Padding(
                      padding: EdgeInsets.fromLTRB(0, topInset + 3, 0, 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              children: [
                                if (_canPop)
                                  SizedBox(
                                    width: kToolbarHeight,
                                    height: kToolbarHeight,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: PlatformHelper.isIOS
                                          ? CupertinoNavigationBarBackButton(
                                              color: primary,
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).maybePop(),
                                            )
                                          : BackButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).maybePop(),
                                            ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 16),
                                Expanded(child: searchBar),
                                const SizedBox(width: 12),
                                CartIconButton(
                                  currentBottomBarIndex:
                                      widget.currentBottomBarIndex,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _skeletonVisible
                                ? const ProductListingChipsSkeleton()
                                : _QuickChipsRow(
                                    selected: _vm.quickFilter,
                                    onSelected: (f) {
                                      HapticFeedback.selectionClick();
                                      _vm.setQuickFilter(f);
                                    },
                                    onSortTap: () {
                                      HapticFeedback.selectionClick();
                                      _openSortPicker();
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if ((_vm.isLoading || _skeletonVisible) && !_vm.hasError)
                    const ProductListingSkeletonSliver()
                  else if (_vm.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _vm.isNetworkError
                          ? NoInternetPage(
                              retryCount: _retryCount,
                              onRetry: () {
                                setState(() => _retryCount++);
                                _vm.load();
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  _vm.errorMessage ?? 'Something went wrong.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: onSurface.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                    )
                  else if (_vm.filteredProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No products found',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    )
                  else
                    ProductGridSliver(
                      products: _vm.filteredProducts,
                      onProductTap: (p) {
                        Navigator.of(context).push(
                          ProductDetailsView.route(
                            product: p,
                            currentBottomBarIndex: widget.currentBottomBarIndex,
                          ),
                        );
                      },
                    ),

                  if (_vm.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 84)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickChipsRow extends StatelessWidget {
  final ProductQuickFilter selected;
  final ValueChanged<ProductQuickFilter> onSelected;
  final VoidCallback onSortTap;

  const _QuickChipsRow({
    required this.selected,
    required this.onSelected,
    required this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final selectedBg = theme.primaryColor.withValues(alpha: 0.10);
    final selectedBorder = theme.primaryColor.withValues(alpha: 0.22);
    final unselectedBorder = theme.dividerColor.withValues(alpha: 0.70);

    Widget sortChip() {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort, size: 16, color: theme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Sort',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          selected: false,
          onSelected: (_) => onSortTap(),
          backgroundColor: theme.colorScheme.surface,
          side: BorderSide(color: unselectedBorder, width: 1),
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          shape: const StadiumBorder(),
        ),
      );
    }

    Widget chip(ProductQuickFilter filter) {
      final isSelected = filter == selected;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(
            filter.label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(filter),
          selectedColor: selectedBg,
          backgroundColor: theme.colorScheme.surface,
          side: BorderSide(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: 1,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          shape: const StadiumBorder(),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.normal,
              ),
              child: Row(
                children: [
                  sortChip(),
                  for (final f in ProductQuickFilter.values) chip(f),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
