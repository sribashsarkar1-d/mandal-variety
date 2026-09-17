import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/platform_helper.dart';
import '../../views/product_listing/product_listing_view.dart';
import '../../views/tobacco/tobacco_age_verification_view.dart';
import '../../data/models/product_model.dart';

class TobaccoAccessCoordinator {
  TobaccoAccessCoordinator._();

  static final TobaccoAccessCoordinator instance = TobaccoAccessCoordinator._();

  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox<dynamic>(_TobaccoAccessKeys.boxName);
  }

  Box<dynamic> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'TobaccoAccessCoordinator not initialized. Call init() first.',
      );
    }
    return box;
  }

  bool get isAgeVerified =>
      _requireBox.get(_TobaccoAccessKeys.kIsVerified) == true;

  Future<void> _setAgeVerified() async {
    await _requireBox.put(_TobaccoAccessKeys.kIsVerified, true);
    await _requireBox.put(
      _TobaccoAccessKeys.kVerifiedAtMillis,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> openTobaccoListing(
    BuildContext context, {
    required int currentBottomBarIndex,
    String? initialQuery,
  }) async {
    await init();

    if (!context.mounted) return;

    final allowed = await _ensureAccess(
      context,
      currentBottomBarIndex: currentBottomBarIndex,
    );
    if (!allowed) return;
    if (!context.mounted) return;

    HapticFeedback.selectionClick();

    Navigator.of(context).push(
      ProductListingView.route(
        // category: ProductCategory.tobacco,
        currentBottomBarIndex: currentBottomBarIndex,
        initialSearchQuery: initialQuery,
      ),
    );
  }

  Future<bool> _ensureAccess(
    BuildContext context, {
    required int currentBottomBarIndex,
  }) async {
    if (!isAgeVerified) {
      final verified = await _runFirstTimeAgeVerification(
        context,
        currentBottomBarIndex: currentBottomBarIndex,
      );
      if (verified != true) return false;
      await _setAgeVerified();
      return true;
    }

    final acknowledged = await _showReturningUserWarningDialog(context);
    return acknowledged == true;
  }

  Future<bool?> _runFirstTimeAgeVerification(
    BuildContext context, {
    required int currentBottomBarIndex,
  }) {
    Widget builder(BuildContext _) => TobaccoAgeVerificationView(
      currentBottomBarIndex: currentBottomBarIndex,
    );

    final route = PlatformHelper.isIOS
        ? CupertinoPageRoute<bool>(builder: builder)
        : MaterialPageRoute<bool>(builder: builder);

    return Navigator.of(context).push<bool>(route);
  }

  Future<bool?> _showReturningUserWarningDialog(BuildContext context) {
    if (PlatformHelper.isIOS) {
      return showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          bool ack = false;

          return StatefulBuilder(
            builder: (ctx, setState) {
              return CupertinoAlertDialog(
                title: const Text('18+ Restricted Products'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    children: [
                      const Text(
                        'Tobacco products are harmful and restricted to 18+ users. Please acknowledge to continue.',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            type: MaterialType.transparency,
                            child: Checkbox(
                              value: ack,
                              onChanged: (v) {
                                HapticFeedback.selectionClick();
                                setState(() => ack = v ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('I understand and want to continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  CupertinoDialogAction(
                    onPressed: ack ? () => Navigator.of(ctx).pop(true) : null,
                    isDefaultAction: true,
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool ack = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final theme = Theme.of(ctx);
            final onSurface = theme.colorScheme.onSurface;

            return AlertDialog(
              title: const Text('18+ Restricted Products'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tobacco products are harmful and restricted to 18+ users. Please acknowledge to continue.',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ack,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => ack = v ?? false);
                    },
                    title: const Text('I understand and want to continue'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: onSurface.withValues(alpha: 0.9)),
                  ),
                ),
                ElevatedButton(
                  onPressed: ack ? () => Navigator.of(ctx).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TobaccoAccessKeys {
  static const String boxName = 'tobacco_access_box';
  static const String kIsVerified = 'is_age_verified';
  static const String kVerifiedAtMillis = 'age_verified_at_millis';
}
