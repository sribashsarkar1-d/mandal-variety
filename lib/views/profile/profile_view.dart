import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/bottombar/common_bottom_bar.dart';
import '../../core/auth/auth_coordinator.dart';
import '../../core/network/network_error_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/profile_model.dart';
import '../../services/api_service.dart';
import '../main/main_view.dart';

class ProfileView extends StatefulWidget {
  final int currentBottomBarIndex;

  const ProfileView({super.key, required this.currentBottomBarIndex});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ApiService _apiService = ApiService();
  late Future<ProfileData> _profileFuture;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<ProfileData> _loadProfile() async {
    final userId = AuthCoordinator.instance.currentUserId;
    if (userId == null) {
      throw const ApiServiceException('Please login to view your profile.');
    }

    try {
      final response = await _apiService.getProfile(userId: userId);
      final data = response.data;
      if (response.success != true || data == null) {
        throw const ApiServiceException('Unable to load profile details.');
      }

      await AuthCoordinator.instance.setUserSession(
        userId: data.id,
        name: data.name,
        email: data.email,
      );

      return data;
    } on ApiServiceException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }

      final snapshotName = AuthCoordinator.instance.currentUserName;
      final snapshotEmail = AuthCoordinator.instance.currentUserEmail;

      if ((snapshotName ?? '').trim().isEmpty &&
          (snapshotEmail ?? '').trim().isEmpty) {
        rethrow;
      }

      return ProfileData(
        id: userId,
        name: (snapshotName ?? '').trim().isEmpty ? 'User' : snapshotName,
        email: snapshotEmail,
      );
    }
  }

  void _retry() {
    setState(() {
      _retryCount += 1;
      _profileFuture = _loadProfile();
    });
  }

  void _onBottomBarTap(BuildContext context, int index) {
    if (index == widget.currentBottomBarIndex) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainView(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'My Profile',
          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
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
      body: FutureBuilder<ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ProfileLoadingState();
          }

          if (snapshot.hasError) {
            final message = snapshot.error.toString();
            return _ProfileErrorState(
              retryCount: _retryCount,
              message: message,
              isNetworkIssue: isNetworkError(snapshot.error),
              onRetry: _retry,
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return _ProfileErrorState(
              retryCount: _retryCount,
              message: 'No profile information is available right now.',
              isNetworkIssue: false,
              onRetry: _retry,
            );
          }

          final name = (profile.name ?? '').trim().isEmpty
              ? 'User'
              : profile.name!.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            physics: const ClampingScrollPhysics(),
            children: [
              _ProfileTopCard(
                name: name,
                email: profile.email,
                phone: profile.phone,
              ),
              const SizedBox(height: 16),
              _ProfileInfoCard(
                title: 'Contact Information',
                rows: [
                  _InfoRowData(label: 'Email', value: profile.email),
                  _InfoRowData(label: 'Phone', value: profile.phone),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                title: 'Address Details',
                rows: [
                  _InfoRowData(label: 'Address', value: profile.address),
                  _InfoRowData(label: 'City', value: profile.city),
                  _InfoRowData(label: 'State', value: profile.state),
                  _InfoRowData(label: 'Country', value: profile.country),
                  _InfoRowData(label: 'Pincode', value: profile.pincode),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                title: 'Account Details',
                rows: [
                  _InfoRowData(label: 'Role', value: profile.role),
                  _InfoRowData(
                    label: 'Member Since',
                    value: _formatDate(profile.createdAt),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Profile edit will be enabled soon.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: onSurface.withValues(alpha: 0.42),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _formatDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;

    final datePart = raw.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length != 3) return raw;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return raw;
    if (month < 1 || month > 12 || day < 1 || day > 31) return raw;

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
}

class _ProfileTopCard extends StatelessWidget {
  final String name;
  final String? email;
  final String? phone;

  const _ProfileTopCard({
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (email ?? phone ?? 'Profile linked with your account').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowData {
  final String label;
  final String? value;

  const _InfoRowData({required this.label, required this.value});
}

class _ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRowData> rows;

  const _ProfileInfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows) ...[
            _InfoRow(label: row.label, value: row.value),
            if (row != rows.last)
              Divider(height: 14, color: onSurface.withValues(alpha: 0.08)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final text = (value ?? '').trim().isEmpty ? 'Not available' : value!.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: onSurface.withValues(alpha: 0.56),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: onSurface.withValues(alpha: 0.76),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.7),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading profile...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  final int retryCount;
  final String message;
  final bool isNetworkIssue;
  final VoidCallback onRetry;

  const _ProfileErrorState({
    required this.retryCount,
    required this.message,
    required this.isNetworkIssue,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkIssue
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 30,
              color: onSurface.withValues(alpha: 0.58),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: onSurface.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryCount > 0 ? 'Retry Again' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
