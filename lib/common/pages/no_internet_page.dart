import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../buttons/app_button.dart';

/// Full-body "No Internet" UI — no Scaffold wrapper.
/// Drop it directly as a Scaffold's body, inside a SliverFillRemaining,
/// or anywhere a Widget is expected.
///
/// [onRetry]      — invoked when the user taps "Try Again".
/// [retryCount]   — parent tracks how many retries have been attempted.
///                  When >= 2 an "Open Network Settings" link appears.
class NoInternetPage extends StatefulWidget {
  final VoidCallback onRetry;
  final int retryCount;

  const NoInternetPage({
    super.key,
    required this.onRetry,
    this.retryCount = 0,
  });

  @override
  State<NoInternetPage> createState() => _NoInternetPageState();
}

class _NoInternetPageState extends State<NoInternetPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final curveColor =
        isDark ? AppColors.charcoalBrown : AppColors.teaGreenSoft;
    final iconColor = isDark ? AppColors.celadon2 : AppColors.dustyOlive;
    final decorColor = isDark ? AppColors.darkSurface : AppColors.celadon2;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _CurvePainter(color: curveColor)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                _Illustration(
                  animation: _floatAnim,
                  iconColor: iconColor,
                  decorColor: decorColor,
                ),
                const Spacer(flex: 2),
                _Headline(
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const Spacer(flex: 2),
                _Actions(
                  onRetry: widget.onRetry,
                  showSettingsLink: widget.retryCount >= 2,
                  onOpenSettings: _openSettings,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Floating Illustration ────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  final Animation<double> animation;
  final Color iconColor;
  final Color decorColor;

  const _Illustration({
    required this.animation,
    required this.iconColor,
    required this.decorColor,
  });

  Widget _circle(double size, {bool outlined = false}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              outlined ? Colors.transparent : decorColor.withValues(alpha: 0.55),
          border: outlined
              ? Border.all(color: iconColor.withValues(alpha: 0.45), width: 2)
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, animation.value),
        child: child,
      ),
      child: SizedBox(
        height: 200,
        width: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative background circles
            Positioned(top: 18, left: 8, child: _circle(26)),
            Positioned(bottom: 8, right: 18, child: _circle(52, outlined: true)),
            Positioned(bottom: 38, left: 18, child: _circle(16, outlined: true)),

            // Floating wifi-off icon (top-left offset)
            Positioned(
              top: 28,
              left: 36,
              child: Icon(
                Icons.wifi_off_rounded,
                color: iconColor.withValues(alpha: 0.7),
                size: 36,
              ),
            ),

            // Main cloud icon (centered)
            Icon(Icons.cloud_off_outlined, size: 140, color: iconColor),

            // No-internet signal icon (overlay)
            Positioned(
              top: 80,
              child: Icon(
                Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                size: 56,
                color: iconColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error Text Content ───────────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  final Color textPrimary;
  final Color textSecondary;

  const _Headline({
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Ooops!',
          style: AppTextStyles.heading1.copyWith(
            color: textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Unable to connect to the server. Please\ncheck your network connection or\ntry again later.",
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            color: textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  final VoidCallback onRetry;
  final bool showSettingsLink;
  final VoidCallback onOpenSettings;

  const _Actions({
    required this.onRetry,
    required this.showSettingsLink,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: AppButton.primary(
            text: 'TRY AGAIN',
            onPressed: onRetry,
          ),
        ),
        if (showSettingsLink) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onOpenSettings,
            icon: Icon(
              Icons.settings_outlined,
              size: 16,
              color: theme.primaryColor,
            ),
            label: Text(
              'Open Network Settings',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Background Curve Painter ─────────────────────────────────────────────────

class _CurvePainter extends CustomPainter {
  final Color color;

  const _CurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Top-left sweep
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.15)
        ..quadraticBezierTo(
          size.width * 0.3,
          size.height * 0.2,
          size.width * 0.5,
          0,
        ),
      paint,
    );

    // Top inner curve
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.1, 0)
        ..quadraticBezierTo(
          size.width * 0.2,
          size.height * 0.1,
          size.width * 0.6,
          -20,
        ),
      paint,
    );

    // Bottom-right sweep
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height * 0.8)
        ..quadraticBezierTo(
          size.width * 0.6,
          size.height * 0.85,
          size.width * 0.7,
          size.height,
        ),
      paint,
    );

    // Bottom-left curve
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.7)
        ..quadraticBezierTo(
          size.width * 0.4,
          size.height * 0.9,
          size.width * 0.3,
          size.height,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => old.color != color;
}
