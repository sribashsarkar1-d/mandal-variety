import 'package:flutter/material.dart';

import '../common/appbar/primary_sliver_app_bar.dart';
import '../common/pages/no_internet_page.dart';
import '../core/network/network_error_utils.dart';
import '../models/categories_model.dart';
import '../models/product_list_model.dart';
import '../services/api_service.dart';
import '../widgets/category_item_widget.dart';
import '../widgets/product_card_widget.dart';
import 'product_detail_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ApiService _apiService = ApiService();

  late Future<_HomePayload> _homeFuture;
  String _selectedCategory = 'All';
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  Future<_HomePayload> _loadHomeData() async {
    final results = await Future.wait<dynamic>([
      _apiService.getCategories(),
      _apiService.getProducts(),
    ]);

    final categories = results[0] as Categories;
    final products = results[1] as ProductList;

    final categoryItems = (categories.data ?? <CategoryItemModel>[])
        .where((item) => (item.isActive ?? 1) == 1)
        .toList();

    final productItems = products.data ?? <Data>[];

    for (final product in productItems) {
      if ((product.categoryName == null || product.categoryName!.trim().isEmpty) &&
          product.categoryId != null) {
        final match = categoryItems.where((c) => c.id == product.categoryId);
        if (match.isNotEmpty) {
          product.categoryName = match.first.name;
        }
      }
    }

    return _HomePayload(categories: categoryItems, products: productItems);
  }

  Future<void> _refresh() async {
    final future = _loadHomeData();
    setState(() => _homeFuture = future);
    await future;
  }

  Future<void> _retryHomeLoad() async {
    setState(() => _retryCount++);
    await _refresh();
  }

  List<Data> _filteredProducts(List<Data> products) {
    if (_selectedCategory.toLowerCase() == 'all') {
      return products;
    }

    return products.where((product) {
      final value = (product.categoryName ?? '').trim().toLowerCase();
      return value == _selectedCategory.toLowerCase();
    }).toList();
  }

  IconData getCategoryIcon(String categoryName) {
    final normalized = categoryName.trim().toLowerCase();

    if (normalized.contains('electronic')) return Icons.devices;
    if (normalized.contains('fashion')) return Icons.checkroom;
    if (normalized.contains('grocery')) return Icons.local_grocery_store;
    if (normalized.contains('beauty')) return Icons.face_retouching_natural;
    if (normalized.contains('book')) return Icons.menu_book;
    if (normalized.contains('furniture')) return Icons.chair;
    if (normalized.contains('toy')) return Icons.toys;
    if (normalized.contains('mobile')) return Icons.smartphone;
    if (normalized.contains('computer') || normalized.contains('laptop')) {
      return Icons.computer;
    }
    if (normalized.contains('watch')) return Icons.watch;

    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<_HomePayload>(
        future: _homeFuture,
        builder: (context, snapshot) {
          final stateSliver = _buildStateSliver(context, snapshot);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                const PrimarySliverAppBar(
                  searchHintText: 'Search products...',
                  searchStaticPrefix: 'Search ',
                  searchAnimatedHints: <String>[
                    'electronics...',
                    'fashion...',
                    'beauty...',
                    'groceries...',
                  ],
                  currentBottomBarIndex: 0,
                ),
                stateSliver,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStateSliver(
    BuildContext context,
    AsyncSnapshot<_HomePayload> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverToBoxAdapter(child: _buildLoadingState());
    }

    if (snapshot.hasError) {
      if (isNetworkError(snapshot.error)) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: NoInternetPage(
            retryCount: _retryCount,
            onRetry: () {
              _retryHomeLoad();
            },
          ),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(
          message: snapshot.error.toString(),
          onRetry: _refresh,
        ),
      );
    }

    final payload = snapshot.data;
    if (payload == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(message: 'No data found.', onRetry: _refresh),
      );
    }

    final categories = payload.categories;
    final products = payload.products;
    final filteredProducts = _filteredProducts(products);

    final categoryNames = <String>{
      ...categories
          .map((e) => (e.name ?? '').trim())
          .where((name) => name.isNotEmpty),
    };

    if (!categoryNames.any((name) => name.toLowerCase() == 'all')) {
      categoryNames.add('All');
    }

    final sortedCategoryNames = categoryNames.toList()
      ..sort((a, b) {
        if (a.toLowerCase() == 'all') return -1;
        if (b.toLowerCase() == 'all') return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    if (categories.isEmpty && products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          title: 'No categories or products found',
          subtitle: 'Pull to refresh or retry.',
          onRetry: _refresh,
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sortedCategoryNames.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final categoryName = sortedCategoryNames[index];
                  final category = categories
                      .cast<CategoryItemModel?>()
                      .firstWhere(
                        (item) =>
                            item?.name?.toLowerCase() ==
                            categoryName.toLowerCase(),
                        orElse: () => null,
                      );

                  final imageUrl = _apiService.resolveImageUrl(category?.image);

                  return CategoryItemWidget(
                    name: categoryName,
                    icon: getCategoryIcon(categoryName),
                    imageUrl: imageUrl,
                    isSelected:
                        _selectedCategory.toLowerCase() ==
                        categoryName.toLowerCase(),
                    onTap: () {
                      setState(() {
                        _selectedCategory = categoryName;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Products',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${filteredProducts.length} items',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              _EmptyState(
                title: 'No products available',
                subtitle: 'Pull to refresh for latest products.',
                onRetry: _refresh,
              )
            else if (filteredProducts.isEmpty)
              _EmptyState(
                title: 'No products in $_selectedCategory',
                subtitle: 'Try selecting All or another category.',
                onRetry: _refresh,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final image = _apiService.resolveImageUrl((product.images != null && product.images!.isNotEmpty) ? product.images!.first : null);
                  final price = product.price == null
                      ? 'Price not available'
                      : 'Rs ${product.price}';
                  final categoryName =
                      (product.categoryName ?? '').trim().isEmpty
                      ? 'Uncategorized'
                      : product.categoryName!.trim();

                  return ProductCardWidget(
                    name: (product.name ?? '').trim().isEmpty
                        ? 'Unnamed Product'
                        : product.name!.trim(),
                    priceText: price,
                    categoryName: categoryName,
                    imageUrl: image,
                    onTap: () {
                      if (product.id == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProductDetailView(productId: product.id!),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerBlock(height: 24, width: 120, radius: 8),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  const _ShimmerBlock(height: 104, width: 86, radius: 16),
            ),
          ),
          const SizedBox(height: 20),
          const _ShimmerBlock(height: 24, width: 100, radius: 8),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemBuilder: (context, index) => const _ShimmerBlock(
              height: 220,
              width: double.infinity,
              radius: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePayload {
  const _HomePayload({required this.categories, required this.products});

  final List<CategoryItemModel> categories;
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 46),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatefulWidget {
  const _ShimmerBlock({
    required this.height,
    required this.width,
    required this.radius,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: Color.lerp(
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.surfaceContainer,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}
