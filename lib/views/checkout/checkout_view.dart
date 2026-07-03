import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/appbar/common_app_bar.dart';
import '../../common/buttons/app_button.dart';
import '../../common/cards/app_card.dart';
import '../../common/snackbars/app_snackbar.dart';
import '../../core/location/address_location_coordinator.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../data/models/address_models.dart';
import '../../models/list_coupons_model.dart';
import '../../viewmodels/cart_viewmodel.dart';
import '../addresses/manual_address_form_view.dart';
import '../../services/api_service.dart';
import '../main/main_view.dart';

class CheckoutView extends StatefulWidget {
  final int currentBottomBarIndex;

  const CheckoutView({super.key, this.currentBottomBarIndex = 0});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  late final CartViewModel _cartVm;

  AddressCache? _addressCache;
  bool _addressLoading = true;

  final TextEditingController _couponCtrl = TextEditingController();
  String? _couponMessage;
  _AppliedCoupon? _appliedCoupon;
  final ApiService _api = ApiService();
  bool _couponsLoading = false;
  bool _applyingCoupon = false;
  List<CouponData> _availableCoupons = const <CouponData>[];
  String? _couponLoadError;

  bool _summaryExpanded = true;
  bool _deliveryOptionsExpanded = false;
  bool _needCarryBag = false;
  String _selectedPaymentMethod = 'Cash on Delivery';
  bool _placingOrder = false;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController();
    _cartVm = CartViewModel();
    _cartVm.init();
    _loadAddressCache();
    _loadCoupons();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _addressCtrl.dispose();
    _cartVm.dispose();
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
        _addressCtrl.text = _addressSubtitle(cache);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _addressLoading = false);
    }
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            visualDensity: VisualDensity.compact,
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

  bool _itemsLikelyInStockForEstimate() {
    return true;
  }

  String _deliveryEstimateText({required bool inStock}) {
    return inStock
        ? 'Delivery in 30–45 minutes.'
        : 'Delivery may take up to 24 hours.';
  }

  void _applyCoupon() {
    _applyCouponByCode(_couponCtrl.text);
  }

  Future<void> _loadCoupons({bool withLoader = true}) async {
    if (withLoader && mounted) {
      setState(() {
        _couponsLoading = true;
        _couponLoadError = null;
      });
    }

    try {
      final response = await _api.getCouponsList();
      final list = (response.data ?? const <CouponData>[])
          .where((c) => (c.code ?? '').trim().isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _availableCoupons = list;
        _couponsLoading = false;
        _couponLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponsLoading = false;
        _couponLoadError = e.toString();
      });
    }
  }

  bool _isExpired(CouponData coupon) {
    final parsed = _parseCouponExpiry(coupon);
    if (parsed == null) return false;

    return parsed.isBefore(DateTime.now());
  }

  DateTime? _parseCouponExpiry(CouponData coupon) {
    final value = (coupon.expiry ?? '').trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  int? _daysUntilExpiry(CouponData coupon) {
    final parsed = _parseCouponExpiry(coupon);
    if (parsed == null) return null;
    return parsed.difference(DateTime.now()).inDays;
  }

  Future<void> _applyCouponByCode(String rawCode) async {
    HapticFeedback.selectionClick();
    final code = rawCode.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _couponMessage = 'Enter a coupon code.';
        _appliedCoupon = null;
      });
      return;
    }

    if (_availableCoupons.isEmpty && !_couponsLoading) {
      await _loadCoupons(withLoader: true);
    }

    final match = _availableCoupons.cast<CouponData?>().firstWhere(
      (c) => (c?.code ?? '').trim().toUpperCase() == code,
      orElse: () => null,
    );

    if (match == null) {
      setState(() {
        _couponMessage = 'Invalid coupon code. Tap "View available".';
        _appliedCoupon = null;
      });
      return;
    }

    if (_isExpired(match)) {
      setState(() {
        _couponMessage = 'Coupon expired.';
        _appliedCoupon = null;
      });
      return;
    }

    if (match.id == null) {
      setState(() {
        _couponMessage = 'Coupon is not applicable right now.';
        _appliedCoupon = null;
      });
      return;
    }

    setState(() {
      _applyingCoupon = true;
      _couponMessage = null;
    });

    try {
      final result = await _api.updateCoupon(
        id: match.id!,
        payload: <String, dynamic>{
          'code': match.code,
          'discount': match.discount,
          'apply': true,
        },
      );

      if (!mounted) return;
      if (result.success == true) {
        _couponCtrl.text = code;
        setState(() {
          _appliedCoupon = _AppliedCoupon(
            id: match.id!,
            code: code,
            percentOff: match.discount,
          );
          _couponMessage =
              result.message ??
              'Coupon applied${match.discount != null ? ': ${match.discount}% off items.' : '.'}';
        });
      } else {
        setState(() {
          _appliedCoupon = null;
          _couponMessage = result.message ?? 'Could not apply coupon.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedCoupon = null;
        _couponMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _applyingCoupon = false);
      }
    }
  }

  Future<void> _openCouponsListSheet() async {
    if (_availableCoupons.isEmpty && !_couponsLoading) {
      await _loadCoupons(withLoader: true);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        final coupons = _availableCoupons
            .toList(growable: false)
          ..sort((a, b) {
            final aExpired = _isExpired(a);
            final bExpired = _isExpired(b);
            if (aExpired != bExpired) return aExpired ? 1 : -1;
            final aDiscount = a.discount ?? 0;
            final bDiscount = b.discount ?? 0;
            return bDiscount.compareTo(aDiscount);
          });

        final activeCoupons = coupons.where((c) => !_isExpired(c)).toList();
        final bestCoupon = activeCoupons.isEmpty
            ? null
            : activeCoupons.reduce((a, b) {
                return (a.discount ?? 0) >= (b.discount ?? 0) ? a : b;
              });

        Widget expiryChip(CouponData coupon) {
          final expired = _isExpired(coupon);
          final daysLeft = _daysUntilExpiry(coupon);

          if (expired) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Expired',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          if (daysLeft != null && daysLeft <= 2) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                daysLeft <= 0 ? 'Ends today' : 'Ends in $daysLeft day(s)',
                style: AppTextStyles.caption.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        }

        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 46,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Available Coupons',
                                    style: AppTextStyles.heading3.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh',
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _loadCoupons(withLoader: true);
                                    if (mounted) {
                                      _openCouponsListSheet();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MiniInfoChip(
                                  icon: Icons.local_offer_outlined,
                                  label: '${coupons.length} total',
                                ),
                                _MiniInfoChip(
                                  icon: Icons.check_circle_outline,
                                  label: '${activeCoupons.length} active',
                                ),
                                if (bestCoupon != null)
                                  _MiniInfoChip(
                                    icon: Icons.bolt_rounded,
                                    label:
                                        'Best ${bestCoupon.discount ?? 0}% OFF',
                                    highlighted: true,
                                  ),
                              ],
                            ),
                            if (_couponLoadError != null)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _couponLoadError!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_couponsLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      )
                    else if (coupons.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 36, 16, 10),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 32,
                                color: onSurface.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No coupons available right now.',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                        sliver: SliverList.separated(
                          itemCount: coupons.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final coupon = coupons[index];
                            final expired = _isExpired(coupon);
                            final code = (coupon.code ?? '').trim().toUpperCase();
                            final discount = coupon.discount ?? 0;
                            final isBest =
                                bestCoupon != null && bestCoupon.id == coupon.id;

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: isBest && !expired
                                    ? LinearGradient(
                                        colors: [
                                          theme.primaryColor.withValues(alpha: 0.16),
                                          theme.primaryColor.withValues(alpha: 0.06),
                                        ],
                                      )
                                    : null,
                              ),
                              child: AppCard(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: expired
                                            ? theme.colorScheme.errorContainer
                                            : theme.primaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.local_offer_rounded,
                                        color: expired
                                            ? theme.colorScheme.onErrorContainer
                                            : theme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  code,
                                                  style: AppTextStyles.bodyLarge.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    color: expired
                                                        ? onSurface.withValues(alpha: 0.45)
                                                        : onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (isBest && !expired)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme.primaryColor,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    'Best',
                                                    style: AppTextStyles.caption.copyWith(
                                                      color: theme.colorScheme.onPrimary,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$discount% off on items',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: onSurface.withValues(alpha: 0.72),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if ((coupon.expiry ?? '').trim().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.event_available_rounded,
                                                    size: 14,
                                                    color: onSurface.withValues(alpha: 0.55),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Valid till: ${coupon.expiry}',
                                                      style: AppTextStyles.caption.copyWith(
                                                        color: onSurface.withValues(alpha: 0.58),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          expiryChip(coupon),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 36,
                                      child: expired
                                          ? OutlinedButton(
                                              onPressed: null,
                                              child: const Text('Expired'),
                                            )
                                          : FilledButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                await _applyCouponByCode(code);
                                              },
                                              child: const Text('Apply'),
                                            ),
                                    ),
                     ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _removeCoupon() {
    HapticFeedback.selectionClick();
    setState(() {
      _appliedCoupon = null;
      _couponMessage = null;
      _couponCtrl.clear();
    });
  }

  double _discountAmount({
    required double itemsSubtotal,
    required _AppliedCoupon? coupon,
  }) {
    if (coupon == null) return 0.0;
    if (coupon.percentOff != null && coupon.percentOff! > 0) {
      return itemsSubtotal * (coupon.percentOff! / 100.0);
    }
    return 0.0;
  }

  Future<void> _placeOrder() async {
    final cache = _addressCache;
    if (cache == null) {
      AppSnackbar.error(context, 'Please wait for address details to load.');
      return;
    }

    final addressStr = _addressCtrl.text.trim();
    if (addressStr.isEmpty ||
        addressStr.toLowerCase().contains('select') ||
        addressStr.toLowerCase().contains('not detected')) {
      AppSnackbar.error(
        context,
        'Please select, add or type a delivery address first.',
      );
      return;
    }

    setState(() => _placingOrder = true);
    HapticFeedback.mediumImpact();

    try {
      final itemsSubtotal = _cartVm.subtotal;
      final coupon = _appliedCoupon;
      final delivery = (coupon?.freeDelivery == true) ? 0.0 : 10.0;
      final discount = _discountAmount(
        itemsSubtotal: itemsSubtotal,
        coupon: coupon,
      );
      final total =
          (itemsSubtotal - discount) +
          delivery +
          _cartVm.handlingCharge +
          _cartVm.smallOrderSurcharge;

      final api = ApiService();
      final res = await api.createOrder(
        address: addressStr,
        paymentMethod: _selectedPaymentMethod,
        totalAmount: total,
      );

      if (res.success == true) {
        // Clear remote and local cart
        await _cartVm.clear();

        if (!mounted) return;

        // Show stunning order success dialog
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: theme.primaryColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Order Created!',
                      style: AppTextStyles.heading2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your order #${res.orderId ?? 'successful'} has been placed successfully.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton.primary(
                      text: 'Track Order',
                      isFullWidth: true,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MainView(initialIndex: 2),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        if (!mounted) return;
        AppSnackbar.error(
          context,
          res.message ?? 'Failed to place order. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _cartVm,
      builder: (context, _) {
        final cache = _addressCache;

        final itemsSubtotal = _cartVm.subtotal;
        final baseDelivery = 10.0;
        final baseHandling = _cartVm.handlingCharge;
        final baseSmallOrder = _cartVm.smallOrderSurcharge;

        final coupon = _appliedCoupon;
        final delivery = (coupon?.freeDelivery == true) ? 0.0 : baseDelivery;
        final discount = _discountAmount(
          itemsSubtotal: itemsSubtotal,
          coupon: coupon,
        );

        final total =
            (itemsSubtotal - discount) +
            delivery +
            baseHandling +
            baseSmallOrder;

        return Scaffold(
          appBar: CommonAppBar(title: 'Checkout'),
          body: SafeArea(
            child: _cartVm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cartVm.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Center(
                      child: Text(
                        'Your cart is empty.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    children: [
                      _CheckoutSectionCard(
                        title: 'Estimated Delivery',
                        trailing: TextButton(
                          onPressed: _openAddressPicker,
                          child: const Text('Change'),
                        ),
                        child: _EstimatedDeliveryContent(
                          addressLoading: _addressLoading,
                          addressTitle: cache == null
                              ? 'Delivery Address'
                              : _addressTitle(cache),
                          addressController: _addressCtrl,
                          onLocateMe: () {
                            _loadAddressCache();
                          },
                          estimateText: _deliveryEstimateText(
                            inStock: _itemsLikelyInStockForEstimate(),
                          ),
                          note:
                              'Delivery times may vary. Holidays not included.',
                          optionsExpanded: _deliveryOptionsExpanded,
                          needCarryBag: _needCarryBag,
                          onToggleExpanded: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _deliveryOptionsExpanded =
                                  !_deliveryOptionsExpanded,
                            );
                          },
                          onCarryBagChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _needCarryBag = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CheckoutSectionCard(
                        title: 'Order Summary',
                        trailing: Tooltip(
                          message: _summaryExpanded ? 'Collapse' : 'Expand',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _summaryExpanded = !_summaryExpanded,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                _summaryExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        child: _SummaryBreakdown(
                          expanded: _summaryExpanded,
                          itemsSubtotal: itemsSubtotal,
                          discount: discount,
                          delivery: delivery,
                          handling: baseHandling,
                          smallOrderSurcharge: baseSmallOrder,
                          total: total,
                        ),
                      ),

                      const SizedBox(height: 12),
                      _CheckoutSectionCard(
                        title: 'Payment Method',
                        child: _PaymentMethodCard(
                          selectedMethod: _selectedPaymentMethod,
                          onChanged: (val) {
                            setState(() {
                              _selectedPaymentMethod = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${AppCurrency.symbol}${total.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton.primary(
                    text: 'Place Order',
                    isFullWidth: true,
                    isLoading: _placingOrder,
                    onPressed: _placingOrder ? null : _placeOrder,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckoutSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _CheckoutSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SummaryBreakdown extends StatelessWidget {
  final bool expanded;
  final double itemsSubtotal;
  final double discount;
  final double delivery;
  final double handling;
  final double smallOrderSurcharge;
  final double total;

  const _SummaryBreakdown({
    required this.expanded,
    required this.itemsSubtotal,
    required this.discount,
    required this.delivery,
    required this.handling,
    required this.smallOrderSurcharge,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    TextStyle rowStyle({bool bold = false, Color? color}) {
      return AppTextStyles.bodyMedium.copyWith(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expanded) ...[
          row(
            'Items Subtotal',
            '${AppCurrency.symbol}${itemsSubtotal.toStringAsFixed(2)}',
          ),
          if (discount > 0)
            row(
              'Discount',
              '-${AppCurrency.symbol}${discount.toStringAsFixed(2)}',
              color: theme.primaryColor,
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
    );
  }
}

class _CouponSection extends StatelessWidget {
  final TextEditingController controller;
  final _AppliedCoupon? appliedCoupon;
  final String? message;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final VoidCallback onViewAvailable;
  final bool isLoading;
  final int availableCount;

  const _CouponSection({
    required this.controller,
    required this.appliedCoupon,
    required this.message,
    required this.onApply,
    required this.onRemove,
    required this.onViewAvailable,
    required this.isLoading,
    required this.availableCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final applied = appliedCoupon != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !applied && !isLoading,
          decoration: InputDecoration(
            hintText: 'Enter coupon code',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onApply(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                applied
                    ? 'Applied: ${appliedCoupon!.code}'
                    : availableCount > 0
                    ? '$availableCount coupons available'
                    : 'Tap "View available" to browse coupons',
                style: AppTextStyles.caption.copyWith(
                  color: onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (applied)
              TextButton(onPressed: onRemove, child: const Text('Remove'))
            else if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              AppButton.outline(text: 'Apply', onPressed: onApply),
          ],
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: isLoading ? null : onViewAvailable,
          icon: const Icon(Icons.local_offer_outlined, size: 18),
          label: const Text('View available/applicable coupons'),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: AppTextStyles.caption.copyWith(
              color: onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const _PaymentMethodCard({
    required this.selectedMethod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Widget buildOption({
      required String title,
      required String subtitle,
      required IconData icon,
      required String value,
    }) {
      final isSelected = selectedMethod == value;
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.primaryColor
                  : theme.dividerColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
            color: isSelected
                ? theme.primaryColor.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withValues(alpha: 0.15)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.primaryColor
                      : onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? theme.primaryColor
                    : onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        buildOption(
          title: 'Cash on Delivery',
          subtitle: 'Pay in cash when your order arrives.',
          icon: Icons.payments_outlined,
          value: 'Cash on Delivery',
        ),
      ],
    );
  }
}

class _EstimatedDeliveryContent extends StatelessWidget {
  final bool addressLoading;
  final String addressTitle;
  final TextEditingController addressController;
  final VoidCallback onLocateMe;
  final String estimateText;
  final String note;
  final bool optionsExpanded;
  final bool needCarryBag;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onCarryBagChanged;

  const _EstimatedDeliveryContent({
    required this.addressLoading,
    required this.addressTitle,
    required this.addressController,
    required this.onLocateMe,
    required this.estimateText,
    required this.note,
    required this.optionsExpanded,
    required this.needCarryBag,
    required this.onToggleExpanded,
    required this.onCarryBagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final optionBg = theme.primaryColor.withValues(alpha: 0.08);
    final optionBorder = theme.dividerColor.withValues(alpha: 0.70);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          addressTitle,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          maxLines: 2,
          minLines: 1,
          style: AppTextStyles.bodyMedium.copyWith(color: onSurface),
          decoration: InputDecoration(
            hintText: 'Enter your delivery address...',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: theme.primaryColor,
              size: 20,
            ),
            suffixIcon: addressLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    color: theme.primaryColor,
                    tooltip: 'Detect Current Location',
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      // Trigger locate me re-detection
                      await AddressLocationCoordinator.instance.locateMeAgain(
                        context,
                      );
                      onLocateMe();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.schedule_rounded,
                size: 20,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estimateText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: AppTextStyles.caption.copyWith(
                      color: onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onToggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'More delivery options',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Icon(
                  optionsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: onSurface.withValues(alpha: 0.70),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (optionsExpanded) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: optionBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: optionBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Need a carry bag?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                ),
                ToggleButtons(
                  borderRadius: BorderRadius.circular(12),
                  constraints: const BoxConstraints(minHeight: 34),
                  isSelected: [needCarryBag, !needCarryBag],
                  onPressed: (index) {
                    onCarryBagChanged(index == 0);
                  },
                  selectedColor: theme.primaryColor,
                  color: onSurface.withValues(alpha: 0.7),
                  fillColor: theme.primaryColor.withValues(alpha: 0.10),
                  borderColor: optionBorder,
                  selectedBorderColor: theme.primaryColor.withValues(
                    alpha: 0.55,
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Yes'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('No'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AppliedCoupon {
  final int id;
  final String code;
  final int? percentOff;
  final bool freeDelivery;

  const _AppliedCoupon({
    required this.id,
    required this.code,
    this.percentOff,
    this.freeDelivery = false,
  });
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;

  const _MiniInfoChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlighted
        ? theme.primaryColor.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHigh;
    final fg = highlighted
        ? theme.primaryColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
