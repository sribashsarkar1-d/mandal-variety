import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_model.dart';
import '../../views/product_listing/product_listing_view.dart';
import '../tobacco/tobacco_access_coordinator.dart';

class ProductListingCoordinator {
  ProductListingCoordinator._();

  static final ProductListingCoordinator instance =
      ProductListingCoordinator._();

  Future<void> openListing(
    BuildContext context, {
    ProductCategory? category,
    int? categoryId,
    required int currentBottomBarIndex,
    String? initialSearchQuery,
  }) async {
    if (!context.mounted) return;

    if (category == ProductCategory.tobacco) {
      await TobaccoAccessCoordinator.instance.openTobaccoListing(
        context,
        currentBottomBarIndex: currentBottomBarIndex,
        initialQuery: initialSearchQuery,
      );
      return;
    }

    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      ProductListingView.route(
        category: category,
        categoryId: categoryId,
        currentBottomBarIndex: currentBottomBarIndex,
        initialSearchQuery: initialSearchQuery,
      ),
    );
  }
}
