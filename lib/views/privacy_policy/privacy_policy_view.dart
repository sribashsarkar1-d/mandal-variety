import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/bottombar/common_bottom_bar.dart';
import '../../common/buttons/cart_icon_button.dart';
import '../../common/pages/no_internet_page.dart';
import '../../core/network/network_error_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/policy_detail_model.dart';
import '../../models/policy_list_model.dart';
import '../../services/api_service.dart';
import '../main/main_view.dart';

// ─────────────────────────────────────────────
// Data model for a Privacy Policy section entry
// ─────────────────────────────────────────────
class _PolicySection {
  final String number;
  final String title;
  final String content;
  final IconData icon;

  const _PolicySection({
    required this.number,
    required this.title,
    required this.content,
    required this.icon,
  });
}

// ─────────────────────────────────────────────
// Expandable row – self-managing expansion state
// ─────────────────────────────────────────────
class _ExpandableSection extends StatefulWidget {
  final _PolicySection section;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.section,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
    if (_expanded) _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    final chipBg = isDark
        ? AppColors.darkPrimary.withValues(alpha: 0.12)
        : AppColors.lightPrimary.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      expanded: _expanded,
      label: widget.section.title,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(16),
        splashColor: primary.withValues(alpha: 0.06),
        highlightColor: primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _expanded
                  ? primary.withValues(alpha: 0.25)
                  : theme.dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────
              Row(
                children: [
                  // Icon chip
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.section.icon, size: 20, color: primary),
                  ),
                  const SizedBox(width: 12),
                  // Title + number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.number,
                          style: AppTextStyles.caption.copyWith(
                            color: primary.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.section.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chevron
                  RotationTransition(
                    turns: _rotateAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: onSurface.withValues(alpha: 0.45),
                      size: 22,
                    ),
                  ),
                ],
              ),
              // ── Expandable content ───────────────────────────
              SizeTransition(
                sizeFactor: _expandAnim,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _expandAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 14),
                        color: onSurface.withValues(alpha: 0.07),
                      ),
                      Text(
                        widget.section.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: onSurface.withValues(alpha: 0.72),
                          height: 1.65,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Main view
// ─────────────────────────────────────────────
class PrivacyPolicyView extends StatefulWidget {
  final int currentBottomBarIndex;

  const PrivacyPolicyView({super.key, required this.currentBottomBarIndex});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  static const int _maxPolicySlugDebugPrints = 6;
  late Future<_PrivacyPolicyPayload> _policyFuture;
  double _scrollProgress = 0.0;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _policyFuture = _loadPolicy();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final progress = (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((progress - _scrollProgress).abs() > 0.005) {
      setState(() => _scrollProgress = progress);
    }
  }

  Future<_PrivacyPolicyPayload> _loadPolicy() async {
    debugPrint(
      '[PrivacyPolicyView] _loadPolicy -> start',
    );
    try {
      final listResponse = await _apiService.getPolicies();

      PolicyListItem? listItem;
      for (final item in listResponse.data ?? const <PolicyListItem>[]) {
        if ((item.slug ?? '').trim().toLowerCase() == 'privacy-policy') {
          listItem = item;
          break;
        }
      }

      if (listItem == null) {
        throw const ApiServiceException('Unable to load Privacy Policy.');
      }

      final detail = PolicyDetailData(
        title: listItem.title,
        content: listItem.content ?? listItem.shortDescription,
        shortDescription: listItem.shortDescription,
      );

      return _PrivacyPolicyPayload(detail: detail, listItem: listItem);
    } catch (e) {
      debugPrint('[PrivacyPolicyView] _loadPolicy <- error: $e');
      rethrow;
    }
  }

  void _retryLoadPolicy() {
    setState(() {
      _retryCount += 1;
      _scrollProgress = 0.0;
      _policyFuture = _loadPolicy();
    });
  }

  List<_PolicySection> _buildSections(PolicyDetailData detail) {
    final rawContent = _sanitizePolicyText(
      (detail.content ?? '').trim().isNotEmpty
          ? detail.content!
          : (detail.shortDescription ?? ''),
    );

    final chunks = _chunkText(rawContent, maxChars: 420, maxChunks: 10);
    if (chunks.isEmpty) {
      return const <_PolicySection>[
        _PolicySection(
          number: 'SECTION 01',
          title: 'Privacy Policy',
          content:
              'No policy details are available right now. Please try again in a moment.',
          icon: Icons.privacy_tip_outlined,
        ),
      ];
    }

    final icons = <IconData>[
      Icons.privacy_tip_outlined,
      Icons.data_usage_rounded,
      Icons.lock_outline_rounded,
      Icons.verified_user_outlined,
      Icons.history_rounded,
      Icons.share_outlined,
      Icons.cookie_outlined,
      Icons.update_rounded,
      Icons.gavel_outlined,
      Icons.rule_folder_outlined,
    ];

    return List<_PolicySection>.generate(chunks.length, (index) {
      final sectionNumber = (index + 1).toString().padLeft(2, '0');
      final title = index == 0
          ? ((detail.title ?? 'Privacy Policy').trim().isEmpty
                ? 'Privacy Policy'
                : detail.title!.trim())
          : 'Policy Details ${index + 1}';
      return _PolicySection(
        number: 'SECTION $sectionNumber',
        title: title,
        content: chunks[index],
        icon: icons[index % icons.length],
      );
    });
  }

  List<String> _chunkText(
    String text, {
    required int maxChars,
    required int maxChunks,
  }) {
    if (text.trim().isEmpty) return const <String>[];

    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (paragraphs.isEmpty) {
      return <String>[text.trim()];
    }

    final result = <String>[];
    final buffer = StringBuffer();

    for (final paragraph in paragraphs) {
      final proposed = buffer.isEmpty
          ? paragraph
          : '${buffer.toString()}\n\n$paragraph';

      if (proposed.length > maxChars && buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
        buffer
          ..clear()
          ..write(paragraph);
      } else {
        if (!buffer.isEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(paragraph);
      }
    }

    if (!buffer.isEmpty) {
      result.add(buffer.toString().trim());
    }

    if (result.length <= maxChunks) {
      return result;
    }

    final head = result.sublist(0, maxChunks - 1);
    final tail = result.sublist(maxChunks - 1).join('\n\n');
    return <String>[...head, tail];
  }

  String _sanitizePolicyText(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw;

    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(
        r'</(p|div|h1|h2|h3|h4|h5|h6|li|ul|ol|section|article|tr)>',
        caseSensitive: false,
      ),
      '\n\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

    const entities = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };

    for (final entry in entities.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    text = text.replaceAll(RegExp(r'\r\n?'), '\n');
    text = text.replaceAll(RegExp(r'[ \t\x0B\f]+'), ' ');
    text = text.replaceAll(RegExp(r'\n[ ]+'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  String _resolveHeaderDescription(_PrivacyPolicyPayload payload) {
    final detailDescription = (payload.detail.shortDescription ?? '').trim();
    if (detailDescription.isNotEmpty) {
      return _sanitizePolicyText(detailDescription);
    }

    final listDescription = (payload.listItem?.shortDescription ?? '').trim();
    if (listDescription.isNotEmpty) {
      return _sanitizePolicyText(listDescription);
    }

    return 'Your privacy matters to us. This policy explains how Mandal Variety Store collects, uses, and protects your personal information.';
  }

  String? _resolveLastUpdated(_PrivacyPolicyPayload payload) {
    final fromDetail = _formatApiDate(payload.detail.updatedAt);
    if (fromDetail != null) return fromDetail;
    return _formatApiDate(payload.detail.createdAt);
  }

  String? _formatApiDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;

    final datePart = raw.split(' ').first;
    final pieces = datePart.split('-');
    if (pieces.length != 3) return null;

    final year = int.tryParse(pieces[0]);
    final month = int.tryParse(pieces[1]);
    final day = int.tryParse(pieces[2]);

    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

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

    return '${monthNames[month - 1]} $day, $year';
  }

  void _onBottomBarTap(BuildContext context, int index) {
    if (index == widget.currentBottomBarIndex) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MainView(initialIndex: index)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;
    final bottomContentSpacer =
        112.0 + MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      // ── App bar ────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: Semantics(
          label: 'Go back',
          button: true,
          child: BackButton(
            color: onSurface,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Privacy Policy',
          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          CartIconButton(
            margin: const EdgeInsets.only(right: 12),
            currentBottomBarIndex: widget.currentBottomBarIndex,
          ),
        ],
        // ── Read progress bar ──────────────────────────────
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (_, _) => LinearProgressIndicator(
              value: _scrollProgress,
              minHeight: 3,
              backgroundColor: onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                primary.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),
      ),
      // ── Bottom bar ─────────────────────────────────────────
      bottomNavigationBar: CommonBottomBar(
        currentIndex: widget.currentBottomBarIndex,
        onTap: (index) => _onBottomBarTap(context, index),
        items: [
          CommonBottomBarItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          CommonBottomBarItem(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: 'Wishlist',
          ),
          CommonBottomBarItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,
            label: 'Orders',
          ),
        ],
      ),
      // ── Body ───────────────────────────────────────────────
      body: FutureBuilder<_PrivacyPolicyPayload>(
        future: _policyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _LoadingState(primary: primary, onSurface: onSurface);
          }

          if (snapshot.hasError) {
            if (isNetworkError(snapshot.error)) {
              return NoInternetPage(
                retryCount: _retryCount,
                onRetry: _retryLoadPolicy,
              );
            }
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _retryLoadPolicy,
            );
          }

          final payload = snapshot.data;
          if (payload == null) {
            return _ErrorState(
              message: 'No privacy policy data was returned.',
              onRetry: _retryLoadPolicy,
            );
          }

          final sections = _buildSections(payload.detail);
          final description = _resolveHeaderDescription(payload);
          final lastUpdated = _resolveLastUpdated(payload);

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero header ─────────────────────────────────
                _HeroHeader(
                  isDark: isDark,
                  primary: primary,
                  onSurface: onSurface,
                  description: description,
                  lastUpdatedLabel: lastUpdated,
                ),
                // ── Sections list ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < sections.length; i++) ...[
                        _ExpandableSection(
                          section: sections[i],
                          initiallyExpanded: i == 0,
                        ),
                        if (i < sections.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                // ── Footer acknowledgment ─────────────────────
                _FooterAcknowledgment(onSurface: onSurface),
                // Safe bottom padding for bottom bar
                SizedBox(height: bottomContentSpacer),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyPolicyPayload {
  final PolicyDetailData detail;
  final PolicyListItem? listItem;

  const _PrivacyPolicyPayload({required this.detail, required this.listItem});
}

// ─────────────────────────────────────────────
// Hero header widget
// ─────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final Color onSurface;
  final String description;
  final String? lastUpdatedLabel;

  const _HeroHeader({
    required this.isDark,
    required this.primary,
    required this.onSurface,
    required this.description,
    required this.lastUpdatedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon + description row ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shield icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.privacy_tip_outlined,
                    size: 28,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 16),
                // Description + last-updated badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: onSurface.withValues(alpha: 0.85),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Last updated badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.update_rounded,
                              size: 13,
                              color: primary.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Last updated: ${lastUpdatedLabel ?? 'Recently'}',
                              style: AppTextStyles.caption.copyWith(
                                color: primary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Footer acknowledgment widget
// ─────────────────────────────────────────────
class _FooterAcknowledgment extends StatelessWidget {
  final Color onSurface;

  const _FooterAcknowledgment({required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Text(
        'By using the Mandal Variety Store app, you consent to the collection and use of your information as described in this Privacy Policy.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: onSurface.withValues(alpha: 0.35),
          height: 1.6,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final Color primary;
  final Color onSurface;

  const _LoadingState({required this.primary, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(
                primary.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading Privacy Policy...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: onSurface.withValues(alpha: 0.62),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: onSurface.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
