import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/utils/platform_helper.dart';
import '../../common/buttons/cart_icon_button.dart';
import '../../common/buttons/wishlist_icon_button.dart';
import '../../common/searchbar/app_search_bar.dart';
import '../../core/tobacco/tobacco_keyword_matcher.dart';
import '../../core/tobacco/tobacco_search_redirector.dart';
import '../../views/product_listing/product_listing_view.dart';
import '../../viewmodels/product_listing_viewmodel.dart';

class CommonSearchCartAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String searchHintText;
  final String? searchStaticPrefix;
  final List<String>? searchAnimatedHints;
  final ValueChanged<String>? onSearchChanged;
  final int currentBottomBarIndex;
  final bool showBackButton;
  final VoidCallback? onBackPress;
  final bool enableTobaccoRedirect;

  const CommonSearchCartAppBar({
    super.key,
    required this.searchHintText,
    this.searchStaticPrefix,
    this.searchAnimatedHints,
    this.onSearchChanged,
    this.currentBottomBarIndex = 0,
    this.showBackButton = true,
    this.onBackPress,
    this.enableTobaccoRedirect = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = showBackButton && canPop;
    final backgroundColor = theme.scaffoldBackgroundColor;

    final searchBar = Container(
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
            onSearchChanged!(q); // If a custom callback is provided, fallback to it
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
    );

    if (PlatformHelper.isIOS) {
      return CupertinoNavigationBar(
        backgroundColor: backgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
        leading: showBack
            ? CupertinoNavigationBarBackButton(
                color: theme.primaryColor,
                onPressed: onBackPress ?? () => Navigator.of(context).pop(),
              )
            : null,
        middle: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: searchBar,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WishlistIconButton(currentBottomBarIndex: currentBottomBarIndex),
            CartIconButton(currentBottomBarIndex: currentBottomBarIndex),
          ],
        ),
      );
    }

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      toolbarHeight: 72,
      leading: showBack
          ? BackButton(
              onPressed: onBackPress ?? () => Navigator.of(context).pop(),
            )
          : null,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 4.0),
        child: Row(
          children: [
            Expanded(child: searchBar),
            const SizedBox(width: 12),
            WishlistIconButton(currentBottomBarIndex: currentBottomBarIndex),
            const SizedBox(width: 4),
            CartIconButton(currentBottomBarIndex: currentBottomBarIndex),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(PlatformHelper.isIOS ? 44 : 72);
}
