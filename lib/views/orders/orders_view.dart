import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/appbar/primary_sliver_app_bar.dart';
import '../../common/buttons/app_button.dart';
import '../../common/drawer/app_drawer.dart';
import '../../common/snackbars/app_snackbar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_currency.dart';
import '../../models/order_models.dart';
import '../../services/api_service.dart';
import '../../viewmodels/orders_viewmodel.dart';
import '../main/main_view.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = ApiService().resolveImageUrl(source).trim();
  if (value.isEmpty) {
    return const AssetImage(_fallbackImageAsset);
  }
  if (value.startsWith('assets/')) {
    return AssetImage(value);
  }
  if (_isHttpUrl(value)) {
    return NetworkImage(value);
  }
  return const AssetImage(_fallbackImageAsset);
}

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> with TickerProviderStateMixin {
  String? _profilePicUrl;
  late final OrdersViewModel _viewModel;
  late AnimationController _emptyStateController;
  late Animation<double> _floatAnimation;


  @override
  void initState() {
    super.initState();
    _viewModel = OrdersViewModel();
    _viewModel.init();

    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _emptyStateController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(
        profilePicUrl: _profilePicUrl,
        currentBottomBarIndex: 2,
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          final list = _viewModel.filteredOrders;
          final allOrders = _viewModel.orders;
          final hasOrders = allOrders.isNotEmpty;
          return RefreshIndicator(
            onRefresh: () async {
              // HapticFeedback.mediumCheck();
              await _viewModel.fetchOrders();
            },
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.normal,
                ),
              ),
              slivers: [
              // ── App Bar ─────────────────────────────
              PrimarySliverAppBar(
                searchHintText: 'Search your orders...',
                searchStaticPrefix: 'Search ',
                searchAnimatedHints: const [
                  'orders...',
                  'order history...',
                  'order status...',
                  'recent orders...',
                  'delivered orders...',
                  'cancelled orders...',
                ],
                onSearchChanged: (val) => debugPrint('Searching orders: $val'),
                currentBottomBarIndex: 2,
                enableTobaccoRedirect: false,
              ),

              if (_viewModel.isLoading && !hasOrders) ...[
                // ── Shimmer Loaders ───────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const _OrderSkeletonCard(),
                      childCount: 3,
                    ),
                  ),
                ),
              ] else if (hasOrders) ...[
                // ── Summary Strip ────────────────────
                SliverToBoxAdapter(
                  child: _OrderSummaryStrip(orders: allOrders),
                ),

                // ── Filter Chips ─────────────────────
                SliverToBoxAdapter(
                  child: _FilterChipRow(
                    selected: _viewModel.selectedFilter,
                    onSelect: (s) {
                      HapticFeedback.selectionClick();
                      if (_viewModel.selectedFilter == s) {
                        _viewModel.setFilter(null);
                      } else {
                        _viewModel.setFilter(s);
                      }
                    },
                  ),
                ),

                // ── Order Cards ──────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (list.isEmpty) {
                          return const _EmptyFilterResult();
                        }
                        return _AnimatedOrderCard(
                          order: list[index],
                          index: index,
                          viewModel: _viewModel,
                        );
                      },
                      childCount: list.isEmpty ? 1 : list.length,
                    ),
                  ),
                ),
              ] else ...[
                // ── Empty State ───────────────────────
                SliverToBoxAdapter(
                  child: _EmptyOrdersState(floatAnimation: _floatAnimation),
                ),
              ],

           
            
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SUMMARY STRIP
// ─────────────────────────────────────────────

class _OrderSummaryStrip extends StatelessWidget {
  final List<OrderListItem> orders;
  const _OrderSummaryStrip({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = orders
        .where((o) {
          final s = o.status?.toLowerCase() ?? 'pending';
          return s == 'pending' || s == '' || s == 'confirmed' || s == 'processing' || s == 'prepare' || s == 'preparing' || s == 'in transit' || s == 'shipped' || s == 'transit';
        })
        .length;
    final delivered = orders
        .where((o) {
          final s = o.status?.toLowerCase() ?? 'pending';
          return s == 'delivered' || s == 'completed' || s == 'success';
        })
        .length;
    final total = orders
        .where((o) {
          final s = o.status?.toLowerCase() ?? 'pending';
          return s != 'cancelled' && s != 'failed';
        })
        .fold<double>(0, (sum, o) => sum + (o.totalAmount ?? 0.0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: 'In Progress',
            value: '$active',
            icon: Icons.local_shipping_rounded,
          ),
          _divider(),
          _SummaryItem(
            label: 'Delivered',
            value: '$delivered',
            icon: Icons.check_circle_rounded,
          ),
          _divider(),
          _SummaryItem(
            label: 'Spent',
            value: '${AppCurrency.symbol}${total.toStringAsFixed(0)}',
            icon: Icons.receipt_long_rounded,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FILTER CHIP ROW
// ─────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _FilterChipRow({
    required this.selected,
    required this.onSelect,
  });

  static const _filters = [
    ('pending', 'Pending'),
    ('confirmed', 'Confirmed'),
    ('processing', 'Processing'),
    ('in transit', 'In Transit'),
    ('delivered', 'Delivered'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: _filters.map((f) {
          final isSelected = selected == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                label: Text(f.$2),
                selected: isSelected,
                onSelected: (_) => onSelect(f.$1),
                selectedColor: theme.primaryColor.withValues(alpha: 0.15),
                checkmarkColor: theme.primaryColor,
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED ORDER CARD
// ─────────────────────────────────────────────

class _AnimatedOrderCard extends StatefulWidget {
  final OrderListItem order;
  final int index;
  final OrdersViewModel viewModel;

  const _AnimatedOrderCard({
    required this.order,
    required this.index,
    required this.viewModel,
  });

  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _pressed = false;

  OrderListItem? _detailedOrder;
  bool _detailsLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 60),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger entry
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _ctrl.forward();
    });

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.order.orderId == null) return;
    if (mounted) setState(() => _detailsLoading = true);
    try {
      final res = await ApiService().getOrderDetail(orderId: widget.order.orderId!);
      if (mounted && res.success == true && res.data != null) {
        setState(() {
          _detailedOrder = res.data;
          _detailsLoading = false;
        });
      } else {
        if (mounted) setState(() => _detailsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _detailsLoading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayOrder = _detailedOrder ?? widget.order;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            _showOrderDetailSheet(context, displayOrder);
          },
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: _OrderCard(
              order: displayOrder,
              isLoadingDetails: _detailedOrder == null && _detailsLoading,
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetailSheet(BuildContext ctx, OrderListItem currentOrder) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final onSurface = theme.colorScheme.onSurface;

        return StatefulBuilder(
          builder: (stCtx, setSheetState) {
            final formattedDate = currentOrder.createdAt != null
                ? '${currentOrder.createdAt!.day}/${currentOrder.createdAt!.month}/${currentOrder.createdAt!.year}'
                : '';

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              expand: false,
              builder: (scrollCtx, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Header ID & Date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order ID: #ORD-${currentOrder.orderId ?? currentOrder.hashCode.toString().substring(0, 4)}',
                                style: AppTextStyles.heading3.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (formattedDate.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Placed on $formattedDate',
                                  style: AppTextStyles.caption.copyWith(
                                    color: onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _StatusBadge(status: currentOrder.status ?? 'pending'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (currentOrder.status?.toLowerCase() == 'confirmed') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, color: Colors.cyan, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Update',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyan[800],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order #ORD-${currentOrder.orderId ?? currentOrder.hashCode.toString().substring(0, 4)}: Your order delivery in 1 hour',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.cyan[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Tracking progress
                    Text(
                      'Order Tracker',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TrackingTimeline(status: currentOrder.status ?? 'pending'),
                    const SizedBox(height: 24),

                    // Items Checklist
                    Text(
                      'Items Ordered (${currentOrder.items?.length ?? 0})',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final item in (currentOrder.items ?? <OrderDetailItem>[])) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image(
                                image: _resolveImageProvider(item.images ?? ''),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  width: 50,
                                  height: 50,
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.image_outlined, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName ?? 'Product',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${AppCurrency.symbol}${item.price?.toStringAsFixed(2)} × ${item.quantity}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${AppCurrency.symbol}${((item.price ?? 0.0) * (item.quantity ?? 1)).toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    const SizedBox(height: 24),

                    // Address Info
                    _SectionTitle(title: 'Delivery Address'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentOrder.address ?? 'No address provided',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment details
                    _SectionTitle(title: 'Payment Information'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      currentOrder.paymentMethod ?? 'Cash on Delivery',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (currentOrder.paymentStatus?.toLowerCase() == 'paid' || 
                                                currentOrder.paymentStatus?.toLowerCase() == 'success' ||
                                                currentOrder.paymentStatus?.toLowerCase() == 'completed')
                                            ? Colors.green.withValues(alpha: 0.15)
                                            : Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (currentOrder.paymentStatus ?? 'Pending').toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: (currentOrder.paymentStatus?.toLowerCase() == 'paid' || 
                                                  currentOrder.paymentStatus?.toLowerCase() == 'success' ||
                                                  currentOrder.paymentStatus?.toLowerCase() == 'completed')
                                              ? Colors.green
                                              : Colors.amber[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentOrder.paymentMethod?.toLowerCase().contains('online') == true
                                      ? 'Paid securely via Online Gateway'
                                      : 'Pay in cash when order is received',
                                  style: AppTextStyles.caption.copyWith(
                                    color: onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Totals
                    _SectionTitle(title: 'Pricing Breakdown'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Subtotal', style: AppTextStyles.bodyMedium),
                        const Spacer(),
                        Text(
                          '${AppCurrency.symbol}${(currentOrder.subtotal ?? 0.0).toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Delivery Charge', style: AppTextStyles.bodyMedium),
                        const Spacer(),
                        Text(
                          '${AppCurrency.symbol}${(currentOrder.deliveryChargeDouble ?? 0.0).toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if ((currentOrder.taxAmountDouble ?? 0.0) > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Tax / GST', style: AppTextStyles.bodyMedium),
                          const Spacer(),
                          Text(
                            '${AppCurrency.symbol}${(currentOrder.taxAmountDouble ?? 0.0).toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Total Amount', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          '${AppCurrency.symbol}${(currentOrder.totalAmount ?? 0.0).toStringAsFixed(2)}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Cancel button
                    if (currentOrder.status == null || currentOrder.status!.trim().isEmpty || currentOrder.status!.trim().toLowerCase() == 'pending') ...[
                      AppButton.outline(
                        text: 'Cancel Order',
                        isFullWidth: true,
                        isLoading: widget.viewModel.isLoading,
                        onPressed: widget.viewModel.isLoading
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: sheetCtx,
                                  builder: (dialogCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Cancel Order'),
                                    content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx, false),
                                        child: const Text('Keep Order'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx, true),
                                        child: Text(
                                          'Cancel Order',
                                          style: TextStyle(color: theme.colorScheme.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final orderIdVal = currentOrder.orderId;
                                  if (orderIdVal != null) {
                                    final success = await widget.viewModel.executeCancelOrder(orderIdVal);
                                    if (success) {
                                      Navigator.pop(sheetCtx); // close bottom sheet
                                      AppSnackbar.success(ctx, 'Order cancelled successfully.');
                                    } else {
                                      AppSnackbar.error(ctx, widget.viewModel.errorMessage ?? 'Failed to cancel order.');
                                    }
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderListItem order;
  final bool isLoadingDetails;

  const _OrderCard({
    required this.order,
    this.isLoadingDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final firstItem = (order.items != null && order.items!.isNotEmpty) ? order.items!.first : null;
    final otherItemsCount = (order.items != null) ? order.items!.length - 1 : 0;
    
    final displayTitle = firstItem?.productName ?? (isLoadingDetails ? 'Loading details...' : 'New Order');
    final displaySubtitle = otherItemsCount > 0
        ? 'and $otherItemsCount other item${otherItemsCount > 1 ? 's' : ''}'
        : 'Ordered Item';

    final formattedDate = order.createdAt != null
        ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}'
        : '';

    final imageVal = firstItem?.images ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image(
                    image: _resolveImageProvider(imageVal),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      width: 72,
                      height: 72,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                  if (isLoadingDetails)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(status: order.status ?? 'pending'),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displaySubtitle,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '#ORD-${order.orderId ?? order.hashCode.toString().substring(0, 4)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (formattedDate.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '•  $formattedDate',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            Text(
                              '• ${(order.paymentStatus ?? 'Pending').toUpperCase()}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: (order.paymentStatus?.toLowerCase() == 'paid' || 
                                        order.paymentStatus?.toLowerCase() == 'success' ||
                                        order.paymentStatus?.toLowerCase() == 'completed')
                                    ? Colors.green
                                    : Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppCurrency.symbol}${(order.totalAmount ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StatusProgressBar(status: order.status ?? 'pending'),
                  if (order.status?.toLowerCase() == 'confirmed') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.cyan, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Order #ORD-${order.orderId ?? order.hashCode.toString().substring(0, 4)}: Your order delivery in 1 hour',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, color, bg) = switch (status.toLowerCase()) {
      'delivered' || 'completed' || 'success' => (
          'Delivered',
          isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          (isDark ? AppColors.darkSuccess : AppColors.lightSuccess).withValues(
            alpha: 0.2,
          ),
        ),
      'in transit' || 'shipped' || 'transit' || 'way' => (
          'In Transit',
          isDark ? AppColors.darkInfo : AppColors.lightInfo,
          (isDark ? AppColors.darkInfo : AppColors.lightInfo).withValues(
            alpha: 0.2,
          ),
        ),
      'processing' || 'prepare' || 'preparing' => (
          'Processing',
          isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2),
          (isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2)).withValues(
            alpha: 0.2,
          ),
        ),
      'confirmed' => (
          'Confirmed',
          isDark ? const Color(0xFF80DEEA) : const Color(0xFF00ACC1),
          (isDark ? const Color(0xFF80DEEA) : const Color(0xFF00ACC1)).withValues(
            alpha: 0.2,
          ),
        ),
      'cancelled' || 'cancel' || 'failed' || 'fail' => (
          'Cancelled',
          isDark ? AppColors.darkError : AppColors.lightError,
          (isDark ? AppColors.darkError : AppColors.lightError).withValues(
            alpha: 0.2,
          ),
        ),
      _ => (
          'Pending',
          isDark ? AppColors.darkWarning : AppColors.lightWarning,
          (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(
            alpha: 0.2,
          ),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATUS PROGRESS BAR
// ─────────────────────────────────────────────

class _StatusProgressBar extends StatelessWidget {
  final String status;
  const _StatusProgressBar({required this.status});

  double get _progress => switch (status.toLowerCase()) {
        'pending' || '' => 0.15,
        'confirmed' => 0.35,
        'processing' || 'prepare' || 'preparing' => 0.55,
        'in transit' || 'shipped' || 'transit' => 0.75,
        'delivered' || 'completed' || 'success' => 1.0,
        _ => 0.0, // cancelled or other
      };

  Color _getColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (status.toLowerCase()) {
      'delivered' || 'completed' || 'success' =>
        isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
      'in transit' || 'shipped' || 'transit' =>
        isDark ? AppColors.darkInfo : AppColors.lightInfo,
      'processing' || 'prepare' || 'preparing' =>
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2),
      'confirmed' =>
        isDark ? const Color(0xFF80DEEA) : const Color(0xFF00ACC1),
      'cancelled' || 'cancel' || 'failed' || 'fail' =>
        isDark ? AppColors.darkError : AppColors.lightError,
      _ => // pending
        isDark ? AppColors.darkWarning : AppColors.lightWarning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final lowercaseStatus = status.toLowerCase();

    if (lowercaseStatus == 'cancelled' || lowercaseStatus == 'failed' || lowercaseStatus == 'cancel') {
      return Row(
        children: [
          Icon(Icons.cancel_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            'Order was cancelled',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyOrdersState extends StatelessWidget {
  final Animation<double> floatAnimation;
  const _EmptyOrdersState({required this.floatAnimation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 8),
      child: Column(
        children: [
          // Floating icon with animated translate
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, floatAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 42,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Your orders live here',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Every purchase you make will show up here.\nStart exploring — something great is waiting.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          AppButton.primary(
            text: 'Start Shopping',
            icon: Icons.storefront_rounded,
            isFullWidth: true,
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainView(initialIndex: 0),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY FILTER RESULT
// ─────────────────────────────────────────────

class _EmptyFilterResult extends StatelessWidget {
  const _EmptyFilterResult();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'No orders match this filter',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SKELETON SHIMMER CARD
// ─────────────────────────────────────────────

class _OrderSkeletonCard extends StatelessWidget {
  const _OrderSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 16,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 50,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TRACKING TIMELINE
// ─────────────────────────────────────────────

class _TrackingTimeline extends StatelessWidget {
  final String status;
  const _TrackingTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final lowercaseStatus = status.toLowerCase();

    if (lowercaseStatus == 'cancelled' || lowercaseStatus == 'cancel' || lowercaseStatus == 'failed') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancelled',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The order has been cancelled and refunded.',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget step({
      required String label,
      required String subtitle,
      required bool completed,
      required bool current,
      required IconData icon,
      bool showLine = true,
    }) {
      final color = completed
          ? theme.primaryColor
          : current
              ? theme.primaryColor.withValues(alpha: 0.6)
              : onSurface.withValues(alpha: 0.2);

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? theme.primaryColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: color,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: completed
                          ? theme.primaryColor
                          : onSurface.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: completed || current ? onSurface : onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: completed || current
                            ? onSurface.withValues(alpha: 0.65)
                            : onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isPending = lowercaseStatus == 'pending' || lowercaseStatus.isEmpty;
    final isConfirmed = lowercaseStatus == 'confirmed';
    final isProcessing = lowercaseStatus == 'processing' || lowercaseStatus.contains('prepare');
    final isInTransit = lowercaseStatus == 'in transit' || lowercaseStatus == 'shipped' || lowercaseStatus.contains('transit');
    final isDelivered = lowercaseStatus == 'delivered' || lowercaseStatus == 'completed' || lowercaseStatus == 'success';

    return Column(
      children: [
        step(
          label: 'Pending',
          subtitle: 'Your order is placed and awaiting approval.',
          completed: isPending || isConfirmed || isProcessing || isInTransit || isDelivered,
          current: isPending,
          icon: Icons.hourglass_empty_rounded,
        ),
        step(
          label: 'Confirmed',
          subtitle: 'Your order has been approved by admin.',
          completed: isConfirmed || isProcessing || isInTransit || isDelivered,
          current: isConfirmed,
          icon: Icons.assignment_turned_in_rounded,
        ),
        step(
          label: 'Processing',
          subtitle: 'We are preparing your package.',
          completed: isProcessing || isInTransit || isDelivered,
          current: isProcessing,
          icon: Icons.receipt_long_rounded,
        ),
        step(
          label: 'In Transit',
          subtitle: 'Your package is on its way.',
          completed: isInTransit || isDelivered,
          current: isInTransit,
          icon: Icons.local_shipping_rounded,
        ),
        step(
          label: 'Delivered',
          subtitle: 'Order received successfully.',
          completed: isDelivered,
          current: isDelivered,
          icon: Icons.check_circle_rounded,
          showLine: false,
        ),
      ],
    );
  }
}
