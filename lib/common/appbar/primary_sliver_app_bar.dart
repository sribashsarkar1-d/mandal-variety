import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../searchbar/app_search_bar.dart';
import '../buttons/cart_icon_button.dart';
import '../buttons/wishlist_icon_button.dart';
import '../../core/tobacco/tobacco_keyword_matcher.dart';
import '../../core/tobacco/tobacco_search_redirector.dart';
import '../../core/utils/platform_helper.dart';
import '../../views/product_listing/product_listing_view.dart';
import '../../viewmodels/product_listing_viewmodel.dart';

class PrimarySliverAppBar extends StatelessWidget {
  final String searchHintText;
  final String? searchStaticPrefix;
  final List<String>? searchAnimatedHints;
  final ValueChanged<String>? onSearchChanged;
  final int? cartItemCount;
  final int currentBottomBarIndex;
  final bool enableTobaccoRedirect;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const PrimarySliverAppBar({
    super.key,
    required this.searchHintText,
    this.searchStaticPrefix,
    this.searchAnimatedHints,
    this.onSearchChanged,
    this.cartItemCount,
    this.currentBottomBarIndex = 0,
    this.enableTobaccoRedirect = true,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.98),
      elevation: 0,
      floating: true,
      pinned: false,
      toolbarHeight: 72,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 4.0),
        child: Row(
          children: [
            if (showBackButton) ...[
              _buildBackButton(context, theme),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AppSearchBar(
                  hintText: searchHintText,
                  staticPrefix: searchStaticPrefix,
                  animatedHints: searchAnimatedHints,
                  onChanged: (q) {
                    if (enableTobaccoRedirect &&
                        TobaccoKeywordMatcher.isTobaccoQuery(q)) {
                      TobaccoSearchRedirector.maybeRedirect(
                        context,
                        q,
                        currentBottomBarIndex: currentBottomBarIndex,
                      );
                      return;
                    }
                    onSearchChanged?.call(q);
                  },
                  onSubmitted: (q) {
                    if (enableTobaccoRedirect &&
                        TobaccoKeywordMatcher.isTobaccoQuery(q)) {
                      TobaccoSearchRedirector.maybeRedirect(
                        context,
                        q,
                        currentBottomBarIndex: currentBottomBarIndex,
                      );
                      return;
                    }
                    if (onSearchChanged != null) {
                      onSearchChanged!(q);
                    } else {
                      Navigator.of(context).push(
                        ProductListingView.route(
                          type: ListingType.search,
                          initialSearchQuery: q,
                        ),
                      );
                    }
                  },
                  onVoiceSubmitted: (q) {
                    if (enableTobaccoRedirect &&
                        TobaccoKeywordMatcher.isTobaccoQuery(q)) {
                      TobaccoSearchRedirector.maybeRedirect(
                        context,
                        q,
                        currentBottomBarIndex: currentBottomBarIndex,
                      );
                      return;
                    }
                    if (onSearchChanged != null) {
                      onSearchChanged!(q);
                    } else {
                      Navigator.of(context).push(
                        ProductListingView.route(
                          type: ListingType.voiceSearch,
                          initialSearchQuery: q,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            WishlistIconButton(currentBottomBarIndex: currentBottomBarIndex),
            const SizedBox(width: 4),
            CartIconButton(currentBottomBarIndex: currentBottomBarIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, ThemeData theme) {
    final onPressed = onBackPressed ?? () => Navigator.maybePop(context);

    if (PlatformHelper.isIOS) {
      return Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: CupertinoButton(
          padding: const EdgeInsets.all(10),
          minSize: 0,
          onPressed: onPressed,
          child: Icon(
            CupertinoIcons.back,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
    );
  }
}
