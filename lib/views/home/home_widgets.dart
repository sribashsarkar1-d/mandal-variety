import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/cards/app_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';

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

class EcommerceSectionTitle extends StatefulWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  const EcommerceSectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  @override
  State<EcommerceSectionTitle> createState() => _EcommerceSectionTitleState();
}

class _EcommerceSectionTitleState extends State<EcommerceSectionTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _arrowAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0.2, 0.0)).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.actionText ?? 'All';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onActionTap != null)
            Material(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onActionTap,
                highlightColor: theme.primaryColor.withValues(alpha: 0.05),
                splashColor: theme.primaryColor.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 6.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SlideTransition(
                        position: _arrowAnimation,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EcommercePromoCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final Function(int)? onPageChanged;
  final VoidCallback? onBannerTap;

  const EcommercePromoCarousel({
    super.key,
    required this.imageUrls,
    this.height = 160.0,
    this.onPageChanged,
    this.onBannerTap,
  });

  @override
  State<EcommercePromoCarousel> createState() => _EcommercePromoCarouselState();
}

class _EcommercePromoCarouselState extends State<EcommercePromoCarousel> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialPage = widget.imageUrls.isNotEmpty
        ? widget.imageUrls.length * 100
        : 0;
    _pageController = PageController(
      viewportFraction: 0.92,
      initialPage: initialPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final realIndex = index % widget.imageUrls.length;
              setState(() => _currentIndex = realIndex);
              if (widget.onPageChanged != null) {
                widget.onPageChanged!(realIndex);
              }
            },
            // Removed itemCount to enable infinite scrolling
            itemBuilder: (context, index) {
              final realIndex = index % widget.imageUrls.length;
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * widget.height,
                      width: double.infinity,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: widget.onBannerTap,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: _resolveImageProvider(widget.imageUrls[realIndex]),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.imageUrls.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              width: _currentIndex == index ? 24.0 : 8.0,
              height: 8.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentIndex == index
                    ? theme.primaryColor
                    : theme.disabledColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EcommerceCategoryItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const EcommerceCategoryItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color:
                  backgroundColor ?? theme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor ?? theme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class EcommerceCategoryRow extends StatelessWidget {
  final List<EcommerceCategoryItem> categories;

  const EcommerceCategoryRow({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      physics: const BouncingScrollPhysics(
        decelerationRate: ScrollDecelerationRate.normal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: SizedBox(
              width:
                  72, // fixed width to keep text aligned and prevent overflow
              child: cat,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EcommerceProductCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final String? discountTag;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const EcommerceProductCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.onTap,
    required this.onAddToCart,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    this.discountTag,
  });

  @override
  State<EcommerceProductCard> createState() => _EcommerceProductCardState();
}

class _EcommerceProductCardState extends State<EcommerceProductCard> {
  bool _isFavorite = false;
  bool _inCart = false;

  void _toggleFavorite() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _handleAddToCart() {
    HapticFeedback.heavyImpact();
    setState(() {
      _inCart = !_inCart;
    });
    widget.onAddToCart();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount =
        widget.originalPrice != null && widget.originalPrice! > widget.price;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;

    return SizedBox(
      width: 160,
      child: AppCard.action(
        onTap: widget.onTap,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Tags Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.12,
                    child: Image(
                      image: _resolveImageProvider(widget.imageUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.discountTag != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.discountTag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Favourite icon placeholder top right
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                    ),
                    color: _isFavorite ? errorColor : Colors.grey[400],
                    onPressed: _toggleFavorite,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isTight = constraints.maxHeight < 104;
                    final double titleRatingGap = isTight ? 2 : 4;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: titleRatingGap),
                        if (widget.rating != null && !isTight)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.rating.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.reviewCount != null)
                                Text(
                                  ' (${widget.reviewCount})',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.disabledColor,
                                  ),
                                ),
                            ],
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${AppCurrency.symbol}${widget.price.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                      height: 1.05,
                                    ),
                                  ),
                                  if (hasDiscount && !isTight)
                                    Text(
                                      '${AppCurrency.symbol}${widget.originalPrice!.toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: theme.disabledColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _handleAddToCart,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    _inCart
                                        ? Icons.shopping_cart
                                        : Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcommerceHorizontalProductList extends StatelessWidget {
  final List<EcommerceProductCard> products;

  const EcommerceHorizontalProductList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          340, // Increased height to prevent bottom overflow with responsive fonts
      child: ListView.separated(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.normal,
        ),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) => products[index],
      ),
    );
  }
}

// Additional reusable components like an Offer Banner
class EcommerceOfferBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const EcommerceOfferBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: _resolveImageProvider(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
