import 'package:mandal_variety/views/age_restriction_policy/age_restriction_policy_view.dart';
import 'package:mandal_variety/views/addresses/my_addresses_view.dart';
import 'package:mandal_variety/views/cancellation_policy/cancellation_policy_view.dart';
import 'package:mandal_variety/views/privacy_policy/privacy_policy_view.dart';
import 'package:mandal_variety/views/profile/profile_view.dart';
import 'package:mandal_variety/views/terms_and_conditions/terms_and_conditions_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/auth/auth_coordinator.dart';
import '../../core/tobacco/tobacco_access_coordinator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/categories_model.dart';
import '../../data/models/product_model.dart';
import '../../services/api_service.dart';
import '../../views/auth/email_login_view.dart';
import '../../views/contact_us/contact_us_view.dart';
import '../../views/onboarding/onboarding_view.dart';
import '../../views/main/main_view.dart';
import '../../views/product_listing/product_listing_view.dart';
import '../dialogs/app_dialog.dart';

const String _fallbackImageAsset = 'assets/logo/mandal_logo.png';

bool _isHttpUrl(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

ImageProvider _resolveImageProvider(String source) {
  final value = source.trim();
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

class AppDrawer extends StatefulWidget {
  final String? profilePicUrl;
  final String? userName; // If null, assume 'Guest User'
  final int? currentBottomBarIndex;

  const AppDrawer({
    super.key,
    this.profilePicUrl,
    this.userName,
    this.currentBottomBarIndex,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _categorySearchController =
      TextEditingController();

  bool _isFaqsExpanded = false;
  late AnimationController _faqsController;
  late Animation<double> _faqsExpandAnim;
  late Animation<double> _faqsRotateAnim;

  bool _isHelpExpanded = false;
  late AnimationController _helpController;
  late Animation<double> _helpExpandAnim;
  late Animation<double> _helpRotateAnim;

  String _appVersion = '';
  String? _drawerName;
  String? _drawerProfilePicUrl;
  bool _isLoadingCategories = true;
  String? _categoriesError;
  List<CategoryItemModel> _drawerCategories = const <CategoryItemModel>[];
  String _categorySearchQuery = '';

  static const String _storeName = 'Mandal Variety';

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How can I place an order?',
      'a':
          'Simply browse products, add them to your cart, and place the order. We currently accept Cash on Delivery (COD) for a smooth and simple experience.',
    },
    {
      'q': 'How will I receive my order?',
      'a':
          'Our local delivery partner will deliver your order directly to your doorstep within the service area of $_storeName.',
    },
    {
      'q': 'How long does delivery take?',
      'a':
          'Most orders are delivered on the same day or within 24 hours, depending on product availability and delivery location.',
    },
    {
      'q': 'Can I cancel my order?',
      'a':
          'Yes, you can cancel your order before it is out for delivery. Please go to the Orders section or contact us directly for quick support.',
    },
    {
      'q': 'What if I receive a damaged item?',
      'a':
          'If you receive a damaged or incorrect product, please contact us immediately. We will review the issue and provide a replacement if applicable.',
    },
    {
      'q': 'Do you accept online payments?',
      'a':
          'Currently, we are accepting Cash on Delivery (COD) only for your convenience. Online payment options may be added in the future.',
    },
    {
      'q': 'Is there a minimum order amount?',
      'a':
          'There may be a minimum order amount depending on the delivery location. Any applicable charges will be shown before placing the order.',
    },
    {
      'q': 'Do you charge for delivery?',
      'a':
          'A small delivery charge may apply based on your area and order value. The final amount will always be visible before confirming your order.',
    },
    {
      'q': 'Can I order tobacco products?',
      'a':
          'Yes, tobacco products are available separately and are strictly for customers aged 18 and above. Age verification may be required at delivery.',
    },
    {
      'q': 'How can I contact $_storeName?',
      'a':
          'You can contact us through the Help section in the app or directly call the shop during working hours for quick assistance.',
    },
  ];

  final List<Map<String, String>> _helpTopics = [
    {
      'title': 'Delivery Areas',
      'desc':
          'We currently deliver within the immediate service area of $_storeName. Check your postal code at checkout.',
    },
    {
      'title': 'Payment Issues',
      'desc':
          'If you face issues finding Cash on Delivery (COD) as an option, ensure your address is within our service area.',
    },
    {
      'title': 'Returns & Refunds',
      'desc':
          'Initiate a return within 3 days for eligible items from the Orders section. We will process it shortly.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDrawerProfile();
    _loadDrawerCategories();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
    _faqsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _faqsExpandAnim = CurvedAnimation(
      parent: _faqsController,
      curve: Curves.easeInOut,
    );
    _faqsRotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _faqsController, curve: Curves.easeInOut),
    );

    _helpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _helpExpandAnim = CurvedAnimation(
      parent: _helpController,
      curve: Curves.easeInOut,
    );
    _helpRotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _helpController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _faqsController.dispose();
    _helpController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context, String actionMessage) {
    HapticFeedback.selectionClick();
  }

  Future<void> _loadDrawerCategories() async {
    if (mounted) {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });
    }

    try {
      final categories = await _apiService.getCategories();
      final items = (categories.data ?? const <CategoryItemModel>[])
          .where((item) => (item.name ?? '').trim().isNotEmpty)
          .toList(growable: false)
        ..sort((left, right) {
          final leftName = (left.name ?? '').trim().toLowerCase();
          final rightName = (right.name ?? '').trim().toLowerCase();
          return leftName.compareTo(rightName);
        });

      if (!mounted) return;
      setState(() {
        _drawerCategories = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoriesError = error.toString();
        _drawerCategories = const <CategoryItemModel>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  String _normalizedCategoryName(String? value) =>
      value?.trim().toLowerCase() ?? '';

  ProductCategory? _knownCategoryFromName(String? categoryName) {
    final value = _normalizedCategoryName(categoryName);
    if (value.contains('grocery')) return ProductCategory.grocery;
    if (value.contains('beauty')) return ProductCategory.beauty;
    if (value.contains('shoe') || value.contains('footwear')) {
      return ProductCategory.shoes;
    }
    if (value.contains('fresh') || value.contains('vegetable')) {
      return ProductCategory.fresh;
    }
    if (value.contains('snack')) return ProductCategory.snacks;
    if (value.contains('drink') || value.contains('beverage')) {
      return ProductCategory.drinks;
    }
    if (value.contains('dairy')) return ProductCategory.dairy;
    if (value.contains('paan') || value.contains('tobacco')) {
      return ProductCategory.tobacco;
    }
    return null;
  }

  IconData _iconFromCategoryName(String? categoryName) {
    final value = _normalizedCategoryName(categoryName);
    if (value.contains('grocery')) return Icons.local_grocery_store_outlined;
    if (value.contains('beauty')) return Icons.face_outlined;
    if (value.contains('shoe') || value.contains('footwear')) {
      return Icons.snowshoeing_outlined;
    }
    if (value.contains('fresh') || value.contains('vegetable')) {
      return Icons.eco_outlined;
    }
    if (value.contains('snack')) return Icons.fastfood_outlined;
    if (value.contains('drink') || value.contains('beverage')) {
      return Icons.local_drink_outlined;
    }
    if (value.contains('dairy')) return Icons.egg_alt_outlined;
    if (value.contains('paan') || value.contains('tobacco')) {
      return Icons.smoking_rooms_outlined;
    }
    return Icons.category_outlined;
  }

  List<CategoryItemModel> get _visibleCategories {
    final query = _categorySearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _drawerCategories;
    }

    return _drawerCategories
        .where((item) {
          final name = (item.name ?? '').trim().toLowerCase();
          final description = (item.description ?? '').trim().toLowerCase();
          return name.contains(query) || description.contains(query);
        })
        .toList(growable: false);
  }

  Map<String, List<CategoryItemModel>> _groupCategories(
    List<CategoryItemModel> categories,
  ) {
    final groups = <String, List<CategoryItemModel>>{};

    for (final category in categories) {
      final name = (category.name ?? '').trim();
      if (name.isEmpty) continue;
      final initial = name.substring(0, 1).toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(initial) ? initial : '#';
      groups.putIfAbsent(key, () => <CategoryItemModel>[]).add(category);
    }

    for (final entry in groups.entries) {
      entry.value.sort((left, right) {
        final leftName = (left.name ?? '').trim().toLowerCase();
        final rightName = (right.name ?? '').trim().toLowerCase();
        return leftName.compareTo(rightName);
      });
    }

    return groups;
  }

  void _openCategory(BuildContext context, CategoryItemModel category) {
    final categoryName = (category.name ?? '').trim();
    if (categoryName.isEmpty) return;

    HapticFeedback.selectionClick();
    Navigator.pop(context);

    final knownCategory = _knownCategoryFromName(categoryName);
    if (knownCategory == ProductCategory.tobacco) {
      TobaccoAccessCoordinator.instance.openTobaccoListing(
        context,
        currentBottomBarIndex: widget.currentBottomBarIndex ?? 0,
      );
      return;
    }

    if (knownCategory != null) {
      Navigator.push(
        context,
        ProductListingView.route(
          category: knownCategory,
          currentBottomBarIndex: widget.currentBottomBarIndex ?? 0,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainView(
          initialIndex: 0,
          initialHomeSearchQuery: categoryName,
        ),
      ),
    );
  }

  List<Widget> _buildCategoriesSection(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _visibleCategories;

    final widgets = <Widget>[];

    if (_drawerCategories.length > 8) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _categorySearchController,
            onChanged: (value) => setState(() => _categorySearchQuery = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search categories',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _categorySearchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _categorySearchController.clear();
                        setState(() => _categorySearchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoadingCategories) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
      return widgets;
    }

    if (_categoriesError != null && categories.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live categories are unavailable right now.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loadDrawerCategories,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
      return widgets;
    }

    if (categories.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            'No categories available right now.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
      return widgets;
    }

    if (_categorySearchQuery.trim().isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Text(
            '${categories.length} matching categories',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

      if (categories.isEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'No categories match your search.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
        return widgets;
      }

      for (final category in categories) {
        widgets.add(_buildCategoryTile(context, category));
      }

      return widgets;
    }

    final groups = _groupCategories(categories);
    final sortedKeys = groups.keys.toList()
      ..sort((left, right) {
        if (left == '#') return right == '#' ? 0 : -1;
        if (right == '#') return 1;
        return left.compareTo(right);
      });

    for (final key in sortedKeys) {
      final groupItems = groups[key] ?? const <CategoryItemModel>[];
      widgets.add(
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            key == '#' ? 'Other categories' : key,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${groupItems.length} items',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
          children: groupItems
              .map((category) => _buildCategoryTile(context, category))
              .toList(growable: false),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCategoryTile(BuildContext context, CategoryItemModel category) {
    final theme = Theme.of(context);
    final categoryName = (category.name ?? '').trim();
    final imageUrl = _apiService.resolveImageUrl(category.image);
    final leadingWidget = imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _CategoryLeadingIcon(
                icon: _iconFromCategoryName(categoryName),
              ),
            ),
          )
        : _CategoryLeadingIcon(icon: _iconFromCategoryName(categoryName));

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: leadingWidget,
      title: Text(
        categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: theme.iconTheme.color?.withValues(alpha: 0.7),
      ),
      onTap: () => _openCategory(context, category),
    );
  }

  Future<void> _loadDrawerProfile() async {
    if (_isGuest) {
      if (!mounted) return;
      setState(() {
        _drawerName = null;
        _drawerProfilePicUrl = null;
      });
      return;
    }

    final sessionName = AuthCoordinator.instance.currentUserName;
    final fallbackName = widget.userName;
    if (mounted) {
      setState(() {
        _drawerName = (sessionName ?? fallbackName ?? '').trim().isEmpty
            ? null
            : (sessionName ?? fallbackName)!.trim();
      });
    }

    try {
      final userId = AuthCoordinator.instance.currentUserId;
      final profile = await _apiService.getProfile(userId: userId);
      final data = profile.data;
      if (!mounted || profile.success != true || data == null) return;

      final resolvedName = (data.name ?? '').trim();
      final rawImage = (data.profileImage ?? '').trim();
      final resolvedImage = rawImage.isEmpty
          ? null
          : _apiService.resolveImageUrl(rawImage);

      await AuthCoordinator.instance.setUserSession(
        userId: data.id,
        name: resolvedName.isEmpty ? null : resolvedName,
        email: data.email,
      );

      if (!mounted) return;
      setState(() {
        if (resolvedName.isNotEmpty) {
          _drawerName = resolvedName;
        }
        _drawerProfilePicUrl = resolvedImage;
      });
    } catch (_) {
      // Keep session fallback values if live profile load fails.
    }
  }

  Future<void> _openProfileOrLogin(BuildContext context) async {
    HapticFeedback.selectionClick();
    Navigator.pop(context);

    if (_isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EmailLoginView(fromDrawer: true),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileView(
          currentBottomBarIndex: widget.currentBottomBarIndex ?? 0,
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Log out',
      message:
          'Are you sure you want to log out? You will need to verify your email again to access your account.',
      confirmText: 'Log out',
      cancelText: 'Cancel',
      barrierDismissible: true,
    );
    if (confirmed != true) return;
    await AuthCoordinator.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingView()),
      (route) => false,
    );
  }

  bool get _isGuest => !AuthCoordinator.instance.isLoggedIn;

  Widget _buildProfileAvatar(BuildContext context, {double radius = 30}) {
    final sessionPic = _drawerProfilePicUrl;
    final widgetPic = widget.profilePicUrl;
    final String? effectivePicUrl = _isGuest
        ? null
        : (sessionPic != null && sessionPic.trim().isNotEmpty
              ? sessionPic
              : (widgetPic != null && widgetPic.trim().isNotEmpty
                    ? widgetPic
                    : null));

    final hasImage = effectivePicUrl != null;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.teaGreenSoft,
      backgroundImage: hasImage ? _resolveImageProvider(effectivePicUrl) : null,
      child: hasImage
          ? null
          : Icon(Icons.person, size: radius * 1.2, color: AppColors.dustyOlive),
    );

    return avatar;
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final theme = Theme.of(context);

    if (_isGuest) {
      return InkWell(
        onTap: () => _openProfileOrLogin(context),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          color: theme.scaffoldBackgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.teaGreenSoft,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 32,
                  color: AppColors.dustyOlive,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hi, Guest!',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Login to view your profile',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.primaryColor,
              ),
            ],
          ),
        ),
      );
    }

    // ── Logged-in header ────────────────────────────────────────────────────
    final sessionName = AuthCoordinator.instance.currentUserName;
    final fallbackName = widget.userName;
    final displayUserName =
        (_drawerName ?? sessionName ?? fallbackName ?? '').trim().isEmpty
        ? 'User'
        : (_drawerName ?? sessionName ?? fallbackName)!.trim();

    return InkWell(
      onTap: () => _openProfileOrLogin(context),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          bottom: 24,
          left: 20,
          right: 20,
        ),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileAvatar(context),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hi, $displayUserName!',
                    style: AppTextStyles.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View or edit your profile',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: theme.disabledColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    bool isDestructive = false,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? (theme.brightness == Brightness.dark
              ? AppColors.darkError
              : AppColors.lightError)
        : theme.iconTheme.color;

    return InkWell(
      onTap: onTap ?? () => _handleTap(context, '$title Clicked'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDestructive
                      ? color
                      : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGuest = _isGuest;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              physics: const ClampingScrollPhysics(),
              children: [
                _buildSectionTitle(context, 'Categories'),
                ..._buildCategoriesSection(context),

                _buildSectionTitle(context, 'Utilities'),
                _buildDrawerItem(
                  context,
                  title: 'My Addresses',
                  icon: Icons.location_on_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyAddressesView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  title: 'Help & Support',
                  icon: Icons.help_outline,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isHelpExpanded = !_isHelpExpanded;
                      if (_isHelpExpanded) {
                        _helpController.forward();
                      } else {
                        _helpController.reverse();
                      }
                    });
                  },
                  trailingWidget: RotationTransition(
                    turns: _helpRotateAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _isHelpExpanded
                          ? theme.primaryColor
                          : theme.iconTheme.color,
                      size: 20,
                    ),
                  ),
                ),
                SizeTransition(
                  sizeFactor: _helpExpandAnim,
                  axisAlignment: -1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02),
                    ),
                    child: Column(
                      children: [
                        ..._helpTopics.map((topic) {
                          return _buildSubItemTile(
                            context,
                            topic['title']!,
                            topic['desc']!,
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 60,
                            right: 20,
                            top: 4,
                            bottom: 16,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContactUsView(
                                      currentBottomBarIndex:
                                          widget.currentBottomBarIndex ?? 0,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: theme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: theme.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Contact Us',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  title: 'FAQs',
                  icon: Icons.question_answer_outlined,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isFaqsExpanded = !_isFaqsExpanded;
                      if (_isFaqsExpanded) {
                        _faqsController.forward();
                      } else {
                        _faqsController.reverse();
                      }
                    });
                  },
                  trailingWidget: RotationTransition(
                    turns: _faqsRotateAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _isFaqsExpanded
                          ? theme.primaryColor
                          : theme.iconTheme.color,
                      size: 20,
                    ),
                  ),
                ),
                SizeTransition(
                  sizeFactor: _faqsExpandAnim,
                  axisAlignment: -1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02),
                    ),
                    child: Column(
                      children: _faqs.map((faq) {
                        return _buildSubItemTile(context, faq['q']!, faq['a']!);
                      }).toList(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  title: 'Contact Us',
                  icon: Icons.contact_support_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactUsView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),

                _buildSectionTitle(context, 'Legal & Trust'),
                _buildDrawerItem(
                  context,
                  title: 'Terms & Conditions',
                  icon: Icons.description_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TermsAndConditionsView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrivacyPolicyView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  title: 'Cancellation Policy',
                  icon: Icons.cancel_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CancellationPolicyView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  title: '18+ Age Restriction Policy',
                  icon: Icons.warning_amber_outlined,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgeRestrictionPolicyView(
                          currentBottomBarIndex:
                              widget.currentBottomBarIndex ?? 0,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),
                if (!isGuest) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    context,
                    title: 'Logout',
                    icon: Icons.logout,
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
              child: Center(
                child: Text(
                  _appVersion.isEmpty
                      ? 'App Version will be shown soon'
                      : 'App Version $_appVersion',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItemTile(
    BuildContext context,
    String title,
    String description,
  ) {
    return _DrawerSubItem(title: title, description: description);
  }
}

class _CategoryLeadingIcon extends StatelessWidget {
  final IconData icon;

  const _CategoryLeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 16,
        color: theme.primaryColor,
      ),
    );
  }
}

class _DrawerSubItem extends StatefulWidget {
  final String title;
  final String description;

  const _DrawerSubItem({required this.title, required this.description});

  @override
  State<_DrawerSubItem> createState() => _DrawerSubItemState();
}

class _DrawerSubItemState extends State<_DrawerSubItem>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 40), // Indent to align with text above
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _expanded
                          ? theme.primaryColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _rotateAnim,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _expanded
                        ? theme.primaryColor
                        : theme.iconTheme.color,
                    size: 20,
                  ),
                ),
              ],
            ),
            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 40,
                  right: 16,
                  top: 8,
                  bottom: 4,
                ),
                child: Text(
                  widget.description,
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
