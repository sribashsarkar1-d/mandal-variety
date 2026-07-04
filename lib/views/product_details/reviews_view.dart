import 'package:flutter/material.dart';

import '../../common/appbar/common_app_bar.dart';
import '../../core/auth/auth_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/product_model.dart';
import '../../models/list_review_model.dart';
import '../../services/api_service.dart';
import 'widgets/review_display_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AllReviewsView
// ─────────────────────────────────────────────────────────────────────────────

class AllReviewsView extends StatefulWidget {
  final ProductModel product;

  const AllReviewsView({super.key, required this.product});

  @override
  State<AllReviewsView> createState() => _AllReviewsViewState();
}

class _AllReviewsViewState extends State<AllReviewsView> {
  final ApiService _apiService = ApiService();

  int _sortIndex = 0;
  bool _isLoading = true;
  String? _loadError;
  List<ReviewDisplayEntry> _reviews = const <ReviewDisplayEntry>[];
  double? _apiAverageRating;
  int? _apiReviewCount;

  static const _sortLabels = ['Most Helpful', 'Latest', 'Positive', 'Negative'];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  int? get _productId => int.tryParse(widget.product.id);

  Future<void> _loadReviews() async {
    final productId = _productId;
    if (productId == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load reviews: invalid product id.';
        _reviews = _fallbackReviews();
        _apiAverageRating = null;
        _apiReviewCount = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await _apiService.getReviewsList(productId: productId);
        final mapped = (response.data ?? const <Data>[])
          .where(_shouldRenderReview)
          .map(_mapApiReview)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _reviews = mapped;
        _apiAverageRating = response.averageRating;
        _apiReviewCount = response.reviewCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
        _reviews = _fallbackReviews();
        _apiAverageRating = null;
        _apiReviewCount = null;
      });
    }
  }

  bool _shouldRenderReview(Data review) {
    final status = (review.status ?? '').trim().toLowerCase();
    if (status.isEmpty) return true;
    return status == 'approved' ||
        status == 'active' ||
        status == 'published' ||
        status == '1' ||
        status == 'pending' ||
        status == '0';
  }

  ReviewDisplayEntry _mapApiReview(Data review) {
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

  List<ReviewDisplayEntry> _fallbackReviews() {
    return widget.product.reviews
        .asMap()
        .entries
        .map(
          (entry) => ReviewDisplayEntry(
            id: 'local-${entry.key}',
            name: entry.value.name,
            rating: entry.value.rating,
            text: entry.value.text,
            title: null,
            isVerified: entry.value.isVerified,
            daysAgo: entry.value.daysAgo,
            createdAt: null,
          ),
        )
        .toList(growable: false);
  }

  int _daysAgoFromIso(String? iso) {
    if ((iso ?? '').trim().isEmpty) return 0;
    final parsed = DateTime.tryParse(iso!.trim());
    if (parsed == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(parsed.toLocal()).inDays;
    return diff < 0 ? 0 : diff;
  }

  DateTime _safeDate(ReviewDisplayEntry review) {
    final parsed = DateTime.tryParse((review.createdAt ?? '').trim());
    if (parsed != null) return parsed;
    return DateTime.now().subtract(Duration(days: review.daysAgo));
  }

  List<ReviewDisplayEntry> get _sortedReviews {
    final list = List<ReviewDisplayEntry>.from(_reviews);
    switch (_sortIndex) {
      case 0:
        list.sort((a, b) {
          final ratingCmp = b.rating.compareTo(a.rating);
          if (ratingCmp != 0) return ratingCmp;
          return _safeDate(b).compareTo(_safeDate(a));
        });
      case 1:
        list.sort((a, b) => _safeDate(b).compareTo(_safeDate(a)));
      case 2:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 3:
        list.sort((a, b) => a.rating.compareTo(b.rating));
    }
    return list;
  }

  List<int> get _distribution {
    final reviews = _reviews;
    return List.generate(
      5,
      (i) => reviews.where((r) => r.rating == 5 - i).length,
    );
  }

  double get _avgRating {
    final apiAvg = _apiAverageRating;
    if (apiAvg != null) {
      return apiAvg.clamp(0.0, 5.0);
    }
    if (_reviews.isEmpty) return 0.0;
    final total = _reviews.fold<int>(0, (sum, rv) => sum + rv.rating);
    return total / _reviews.length;
  }

  int get _totalRatings => _apiReviewCount ?? _reviews.length;



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outline.withValues(alpha: 0.15);
    final reviews = _sortedReviews;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CommonAppBar(title: 'All Reviews'),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : reviews.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No reviews available for this product yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _loadError!,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _loadReviews,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_loadError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Using fallback data. ${_loadError!}',
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: RatingSummaryCard(
                      avgRating: _avgRating,
                      totalRatings: _totalRatings,
                      reviewCount: _reviews.length,
                      distribution: _distribution,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User reviews sorted by',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PillChipRow(
                          labels: _sortLabels,
                          selectedIndex: _sortIndex,
                          onSelect: (i) => setState(() => _sortIndex = i),
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, thickness: 1, color: dividerColor),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + bottomInset),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReviewDisplayCard(entry: reviews[i]),
                      ),
                      childCount: reviews.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AddReviewSheet extends StatefulWidget {
  const AddReviewSheet({super.key, required this.onSubmit});

  final Future<dynamic> Function(int rating, String title, String comment)
  onSubmit;

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || _selectedRating <= 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final title = _titleController.text.trim();
      final result = await widget.onSubmit(
        _selectedRating,
        title.isEmpty ? 'Review' : title,
        comment,
      );

      if (!mounted) return;
      final success = result?.success == true;
      final message = (result?.message ?? '').toString().trim();

      if (success) {
        Navigator.of(
          context,
        ).pop(message.isEmpty ? 'Review submitted successfully.' : message);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Could not submit review.' : message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit =
        _selectedRating > 0 && _commentController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Write a review',
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your rating',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final starValue = i + 1;
                final active = starValue <= _selectedRating;
                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                          _selectedRating = starValue;
                        }),
                  icon: Icon(
                    active ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: active
                        ? (theme.brightness == Brightness.dark
                              ? AppColors.darkWarning
                              : AppColors.lightWarning)
                        : theme.disabledColor,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              maxLines: 4,
              minLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Your review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit && !_isSubmitting ? _handleSubmit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PillChipRow — horizontally scrollable row of pill-shaped selector chips
// ─────────────────────────────────────────────────────────────────────────────

class _PillChipRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _PillChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: labels.length,
        itemBuilder: (_, index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: index < labels.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : onSurface.withValues(alpha: 0.25),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  labels[index],
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? primary
                        : onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
