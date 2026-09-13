import 'package:flutter/material.dart';

import '../common/pages/no_internet_page.dart';
import '../core/network/network_error_utils.dart';
import '../models/list_review_model.dart' as review_model;
import '../models/product_details_model.dart';
import '../services/api_service.dart';
import 'product_details/widgets/review_display_widgets.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final ApiService _apiService = ApiService();
  late Future<_ProductDetailApiBundle> _detailsFuture;

  int _activeIndex = 0;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadProductData();
  }

  Future<_ProductDetailApiBundle> _loadProductData() async {
    final detailFuture = _apiService.getProductDetails(widget.productId);
    final reviewFuture = _apiService.getReviewsList(productId: widget.productId);

    final detail = await detailFuture;

    // Reviews should not block product detail rendering if this endpoint fails.
    review_model.ListReview? reviewResponse;
    try {
      reviewResponse = await reviewFuture;
    } catch (_) {
      reviewResponse = null;
    }

    return _ProductDetailApiBundle(details: detail, reviews: reviewResponse);
  }

  Future<void> _refresh() async {
    final future = _loadProductData();
    setState(() => _detailsFuture = future);
    await future;
  }

  Future<void> _retryDetailsLoad() async {
    setState(() => _retryCount++);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: FutureBuilder<_ProductDetailApiBundle>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            if (isNetworkError(snapshot.error)) {
              return NoInternetPage(
                retryCount: _retryCount,
                onRetry: () {
                  _retryDetailsLoad();
                },
              );
            }
            return _DetailErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final payload = snapshot.data;
          final details = payload?.details.data;
          if (details == null) {
            return _DetailErrorState(
              message: 'Product details not found.',
              onRetry: _refresh,
            );
          }

          final averageRating = payload?.reviews?.averageRating;
          final reviewCount = payload?.reviews?.reviewCount;
            final allReviewEntries =
              (payload?.reviews?.data ?? const <review_model.Data>[])
                .where(_shouldRenderReview)
                .map(_mapApiReview)
                .toList(growable: false);
            final sortedReviewEntries = _sortReviewsMostHelpful(allReviewEntries);
            final previewReviews =
              sortedReviewEntries.take(3).toList(growable: false);
            final resolvedAverageRating =
              averageRating ?? _avgFromReviews(allReviewEntries);
            final resolvedReviewCount = reviewCount ?? allReviewEntries.length;
            final ratingDistribution = _ratingDistribution(allReviewEntries);

          final images = (details.images ?? <String>[])
              .map(_apiService.resolveImageUrl)
              .where((e) => e.trim().isNotEmpty)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildImageSlider(images),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (details.name ?? '').trim().isEmpty
                            ? 'Unnamed Product'
                            : details.name!.trim(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if ((details.shortDescription ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          details.shortDescription!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if ((details.parentCategoryName ?? '').trim().isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _metaChip(context, details.parentCategoryName!.trim()),
                            if ((details.childCategoryName ?? '').trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              _metaChip(context, details.childCategoryName!.trim()),
                            ],
                          ],
                        ),
                      ] else ...[
                        _metaChip(
                          context,
                          (details.categoryName ?? '').trim().isEmpty
                              ? 'Uncategorized'
                              : details.categoryName!.trim(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(details.price),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          if ((details.discountPrice ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                _formatPrice(details.discountPrice),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (resolvedAverageRating != null ||
                          resolvedReviewCount > 0)
                        RatingSummaryCard(
                          avgRating: resolvedAverageRating ?? 0.0,
                          totalRatings: resolvedReviewCount,
                          reviewCount: resolvedReviewCount,
                          distribution: ratingDistribution,
                        ),
                      if (resolvedAverageRating != null ||
                          resolvedReviewCount > 0)
                        const SizedBox(height: 14),
                      _buildInfoRow('SKU', details.sku),
                      _buildInfoRow(
                        'Stock',
                        _stockText(details.stockQuantity, details.stock),
                      ),
                      const SizedBox(height: 14),
                      _buildProductMetaSection(context, details),
                      const SizedBox(height: 18),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (details.description ?? '').trim().isEmpty
                            ? 'No description available.'
                            : details.description!.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (previewReviews.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Top Reviews (Max 3)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        for (final review in previewReviews) ...[
                          ReviewDisplayCard(entry: review),
                          if (review != previewReviews.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 280,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _activeIndex == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: _activeIndex == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final displayValue = (value ?? '').trim().isEmpty ? 'N/A' : value!.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }

  bool _shouldRenderReview(review_model.Data review) {
    final status = (review.status ?? '').trim().toLowerCase();
    if (status.isEmpty) return true;
    return status == 'approved' ||
        status == 'active' ||
        status == 'published' ||
        status == '1';
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

  List<ReviewDisplayEntry> _sortReviewsMostHelpful(
    List<ReviewDisplayEntry> reviews,
  ) {
    final list = List<ReviewDisplayEntry>.from(reviews);
    DateTime safeDate(ReviewDisplayEntry review) {
      final parsed = DateTime.tryParse((review.createdAt ?? '').trim());
      if (parsed != null) return parsed;
      return DateTime.now().subtract(Duration(days: review.daysAgo));
    }

    list.sort((a, b) {
      final ratingCmp = b.rating.compareTo(a.rating);
      if (ratingCmp != 0) return ratingCmp;
      return safeDate(b).compareTo(safeDate(a));
    });
    return list;
  }

  List<int> _ratingDistribution(List<ReviewDisplayEntry> reviews) {
    return List<int>.generate(
      5,
      (i) => reviews.where((r) => r.rating == 5 - i).length,
    );
  }

  double? _avgFromReviews(List<ReviewDisplayEntry> reviews) {
    if (reviews.isEmpty) return null;
    final total = reviews.fold<int>(0, (sum, rv) => sum + rv.rating);
    return total / reviews.length;
  }

  Widget _buildProductMetaSection(BuildContext context, Data details) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    final chips = <Widget>[];
    if (details.couponApplicable != null) {
      chips.add(
        _statusChip(
          context,
          details.couponApplicable == true
              ? 'Coupon applicable'
              : 'Coupon not applicable',
          details.couponApplicable == true
              ? primary
              : onSurfaceVariant,
        ),
      );
    }
    if (details.isInStock != null) {
      chips.add(
        _statusChip(
          context,
          details.isInStock == true ? 'In stock' : 'Out of stock',
          details.isInStock == true
              ? Colors.green
              : theme.colorScheme.error,
        ),
      );
    }
    if (details.freeDelivery != null) {
      chips.add(
        _statusChip(
          context,
          details.freeDelivery == true ? 'Free delivery' : 'Delivery charge applies',
          details.freeDelivery == true
              ? Colors.green
              : onSurfaceVariant,
        ),
      );
    }

    final rows = <_MetaRow>[
      if ((details.brand ?? '').trim().isNotEmpty)
        _MetaRow('Brand', details.brand!.trim()),
      if ((details.unitLabel ?? '').trim().isNotEmpty)
        _MetaRow('Unit', details.unitLabel!.trim()),
      if ((details.countryOfOrigin ?? '').trim().isNotEmpty)
        _MetaRow('Country of origin', details.countryOfOrigin!.trim()),
      if ((details.deliveryType ?? '').trim().isNotEmpty)
        _MetaRow('Delivery type', details.deliveryType!.trim()),
      if ((details.estimatedDeliveryTime ?? '').trim().isNotEmpty)
        _MetaRow(
          'Estimated delivery',
          details.estimatedDeliveryTime!.trim(),
        ),
      if (details.discountPercentage != null)
        _MetaRow(
          'Discount',
          '${details.discountPercentage}% off',
        ),
      if (details.deliveryCharge != null)
        _MetaRow(
          'Delivery charge',
          'Rs ${details.deliveryCharge}',
        ),
      if (details.maxOrderQuantity != null)
        _MetaRow(
          'Max order',
          '${details.maxOrderQuantity}',
        ),
      if (details.minOrderQuantity != null)
        _MetaRow(
          'Min order',
          '${details.minOrderQuantity}',
        ),
      if (details.expiryDate != null)
        _MetaRow('Expiry date', _formatDate(details.expiryDate)),
      if (details.manufacturingDate != null)
        _MetaRow('Manufactured on', _formatDate(details.manufacturingDate)),
    ];

    final rowWidgets = rows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    row.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: row.valueColor ?? onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false);

    if (chips.isEmpty && rowWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Highlights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
          if (rowWidgets.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...rowWidgets,
          ],
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatPrice(String? rawPrice) {
    if ((rawPrice ?? '').trim().isEmpty) {
      return 'Price unavailable';
    }
    return 'Rs ${rawPrice!.trim()}';
  }

  String _stockText(int? stockQuantity, int? stock) {
    final resolved = stockQuantity ?? stock;
    if (resolved == null) return 'Unknown';
    if (resolved <= 0) return 'Out of stock';
    return '$resolved available';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

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

class _MetaRow {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaRow(this.label, this.value, {this.valueColor});
}

class _ProductDetailApiBundle {
  final Productdetails details;
  final review_model.ListReview? reviews;

  const _ProductDetailApiBundle({required this.details, required this.reviews});
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

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
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
