import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/responsive/media_query_helper.dart';
import '../../core/auth/auth_coordinator.dart';
import '../../views/auth/email_login_view.dart';
import '../../views/main/main_view.dart';
import '../../viewmodels/splash_viewmodel.dart';
import '../../services/api_service.dart';
import '../../services/api_cache_service.dart';

// ============================================================================
// MANDAL VARIETY — SPLASH SCREEN
// Brand-aligned, illustration-quality animated splash
// ============================================================================

// ============================================================================
// SPLASH SCREEN — STATE & ANIMATION ORCHESTRATION
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final SplashViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SplashViewModel(
      vsync: this,
      onComplete: _navigateToMain,
    );
    _prefetchHomeData();
  }

  Future<void> _prefetchHomeData() async {
    final apiService = ApiService();
    final cacheService = ApiCacheService.instance;
    await cacheService.init();

    try {
      final hierarchy = await apiService.getCategoryHierarchy();
      await cacheService.cacheJson('home_hierarchy', hierarchy.toJson());
    } catch (_) {}

    try {
      final banners = await apiService.getBanners();
      await cacheService.cacheJson('home_banners', banners.toJson());
    } catch (_) {}

    try {
      final products = await apiService.getProducts();
      await cacheService.cacheJson('home_products', products.toJson());
    } catch (_) {}
  }

  void _navigateToMain() {
    if (!mounted) return;
    final auth = AuthCoordinator.instance;
    Widget dest;
    if (auth.isLoggedIn) {
      dest = const MainView();
    } else {
      dest = const EmailLoginView();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size       = MediaQuery.of(context).size;
    MediaQueryHelper.init(context);
    final phoneW     = size.width * 0.52;
    final phoneH     = phoneW * 2.05;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _vm.listenable,
        builder: (context, _) {
          return Stack(
            children: [

              // ── LAYERED BACKGROUND ───────────────────────────────────────
              _buildBackground(size),

              // ── DECORATIVE FLOATING LEAVES ───────────────────────────────
              _buildDecorativeLeaves(size),

              // ── SCOOTER (behind phone) ────────────────────────────────────
              Align(
                alignment: Alignment(_vm.scooterX.value, 0.24),
                child: Opacity(
                  opacity: _vm.scooterOpacity.value.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: Size(size.width * 0.55, size.width * 0.38),
                    painter: RealisticScooterPainter(),
                  ),
                ),
              ),

              // ── PHONE FRAME ───────────────────────────────────────────────
              Center(
                child: _buildPhoneFrame(phoneW, phoneH),
              ),

              // ── BOTTOM BRAND SECTION ──────────────────────────────────────
              _buildBottomBrandSection(size),
            ],
          );
        },
      ),
    );
  }

  // ── BACKGROUND ─────────────────────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    final pulseT = _vm.bgPulse.value;
    final c1 = Color.lerp(
      AppColors.teaGreenSoft,
      AppColors.celadon2,
      pulseT * 0.3,
    )!;
    final c2 = Color.lerp(
      AppColors.celadon1,
      AppColors.mutedTeal,
      pulseT * 0.25,
    )!;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2, AppColors.celadon1.withOpacity(0.7)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        size: size,
        painter: BackgroundPatternPainter(pulse: pulseT),
      ),
    );
  }

  // ── DECORATIVE LEAVES ───────────────────────────────────────────────────────
  Widget _buildDecorativeLeaves(Size size) {
    return Stack(
      children: [
        // Top-left leaf cluster
        Positioned(
          top: size.height * 0.04,
          left: size.width * (0.03 + _vm.leaf1X.value),
          child: Transform.rotate(
            angle: _vm.leaf1Rot.value,
            child: CustomPaint(
              size: const Size(90, 70),
              painter: DecorativeLeafPainter(
                baseColor: AppColors.dustyOlive,
                accentColor: AppColors.celadon1,
              ),
            ),
          ),
        ),
        // Top-right leaf
        Positioned(
          top: size.height * 0.06,
          right: size.width * (0.04 + _vm.leaf2X.value.abs()),
          child: Transform.rotate(
            angle: math.pi + _vm.leaf2Rot.value,
            child: CustomPaint(
              size: const Size(70, 55),
              painter: DecorativeLeafPainter(
                baseColor: AppColors.mutedTeal,
                accentColor: AppColors.dustyOlive,
              ),
            ),
          ),
        ),
        // Bottom-left leaf
        Positioned(
          bottom: size.height * 0.14,
          left: size.width * (0.02 + _vm.leaf2X.value.abs()),
          child: Transform.rotate(
            angle: 0.4 + _vm.leaf1Rot.value,
            child: CustomPaint(
              size: const Size(60, 46),
              painter: DecorativeLeafPainter(
                baseColor: AppColors.dustyOlive2,
                accentColor: AppColors.celadon2,
              ),
            ),
          ),
        ),
        // Bottom-right leaf
        Positioned(
          bottom: size.height * 0.16,
          right: size.width * (0.03 + _vm.leaf1X.value.abs()),
          child: Transform.rotate(
            angle: -0.6 + _vm.leaf2Rot.value,
            child: CustomPaint(
              size: const Size(75, 58),
              painter: DecorativeLeafPainter(
                baseColor: AppColors.dustyOlive,
                accentColor: AppColors.teaGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PHONE FRAME ─────────────────────────────────────────────────────────────
  Widget _buildPhoneFrame(double phoneW, double phoneH) {
    return Container(
      width: phoneW,
      height: phoneH,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: AppColors.carbonBlack, width: 5),
        boxShadow: [
          BoxShadow(
            color: AppColors.carbonBlack.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.teaGreen.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Phone screen content
          ClipRRect(
            borderRadius: BorderRadius.circular(37),
            child: _buildPhoneScreenContent(phoneW, phoneH),
          ),

          // Dynamic Island / Notch
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: phoneW * 0.32,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.carbonBlack,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),

          // Side buttons simulation
          Positioned(
            right: -5,
            top: phoneH * 0.22,
            child: _sideButton(height: 50),
          ),
          Positioned(
            left: -5,
            top: phoneH * 0.28,
            child: _sideButton(height: 36),
          ),
          Positioned(
            left: -5,
            top: phoneH * 0.34,
            child: _sideButton(height: 36),
          ),
        ],
      ),
    );
  }

  Widget _sideButton({required double height}) {
    return Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.charcoalBrown,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ── PHONE SCREEN CONTENT ───────────────────────────────────────────────────
  Widget _buildPhoneScreenContent(double phoneW, double phoneH) {
    return Container(
      width: phoneW,
      height: phoneH,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lightSurface,
            Color(0xFFE8F2E8),
            AppColors.lightBackground,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle grid texture on screen
          CustomPaint(
            size: Size(phoneW, phoneH),
            painter: ScreenTexturePainter(),
          ),

          // ── Basket (foreground, anchored at bottom) ──────────────────────
          Align(
            alignment: Alignment(0.0, _vm.basketY.value),
            child: Transform.scale(
              scale: _vm.basketScale.value.clamp(0.0, 1.0),
              child: CustomPaint(
                size: Size(phoneW * 0.78, phoneH * 0.22),
                painter: RealisticBasketPainter(),
              ),
            ),
          ),

          // ── Grocery Items ────────────────────────────────────────────────

          // Milk Carton
          Align(
            alignment: Alignment(-0.38, _vm.milkY.value),
            child: Opacity(
              opacity: _vm.milkOpacity.value.clamp(0.0, 1.0),
              child: CustomPaint(
                size: const Size(62, 96),
                painter: RealisticMilkCartonPainter(),
              ),
            ),
          ),

          // Apple
          Align(
            alignment: Alignment(0.42, _vm.appleY.value),
            child: Opacity(
              opacity: _vm.appleOpacity.value.clamp(0.0, 1.0),
              child: CustomPaint(
                size: const Size(66, 72),
                painter: RealisticApplePainter(),
              ),
            ),
          ),

          // Croissant
          Align(
            alignment: Alignment(0.08, _vm.croissantY.value),
            child: Opacity(
              opacity: _vm.croissantOpacity.value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.18,
                child: CustomPaint(
                  size: const Size(90, 56),
                  painter: RealisticCroissantPainter(),
                ),
              ),
            ),
          ),

          // Bread Loaf
          Align(
            alignment: Alignment(-0.35, _vm.breadY.value),
            child: Opacity(
              opacity: _vm.breadOpacity.value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: 0.08,
                child: CustomPaint(
                  size: const Size(96, 52),
                  painter: RealisticBreadPainter(),
                ),
              ),
            ),
          ),

          // Baguette
          Align(
            alignment: Alignment(0.36, _vm.baguetteY.value),
            child: Opacity(
              opacity: _vm.baguetteOpacity.value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: 0.42,
                child: CustomPaint(
                  size: const Size(42, 118),
                  painter: RealisticBaguettePainter(),
                ),
              ),
            ),
          ),

          // Tomato
          Align(
            alignment: Alignment(-0.10, _vm.tomatoY.value),
            child: Opacity(
              opacity: _vm.tomatoOpacity.value.clamp(0.0, 1.0),
              child: CustomPaint(
                size: const Size(58, 62),
                painter: RealisticTomatoPainter(),
              ),
            ),
          ),

          // ── In-screen brand header ───────────────────────────────────────
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: _buildInScreenHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildInScreenHeader() {
    return Opacity(
      opacity: _vm.logoFade.value.clamp(0.0, 1.0),
      child: Column(
        children: [
          // Small logo mark
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightPrimary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.carbonBlack.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.teaGreen, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            'MANDAL',
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'serif',
              fontWeight: FontWeight.w800,
              letterSpacing: 3.5,
              color: AppColors.carbonBlack,
              shadows: [
                Shadow(
                  color: AppColors.carbonBlack.withOpacity(0.12),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM BRAND SECTION ────────────────────────────────────────────────────
  Widget _buildBottomBrandSection(Size size) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: size.height * 0.20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.celadon1.withOpacity(0.4),
              AppColors.dustyOlive.withOpacity(0.85),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand wordmark
            Transform.translate(
              offset: Offset(0, _vm.logoSlide.value),
              child: Opacity(
                opacity: _vm.logoFade.value.clamp(0.0, 1.0),
                child: Text(
                  'Mandal Variety',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.lightSurface,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: AppColors.carbonBlack.withOpacity(0.45),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Tagline
            Opacity(
              opacity: _vm.taglineFade.value.clamp(0.0, 1.0),
              child: Text(
                'groceries delivered fast to your doorstep',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.teaGreen.withOpacity(0.92),
                  letterSpacing: 0.4,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Loading dots
            Opacity(
              opacity: _vm.taglineFade.value.clamp(0.0, 1.0),
              child: _buildLoadingDots(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    Widget dot(double scale) => Transform.scale(
      scale: (0.5 + scale * 0.5).clamp(0.5, 1.0),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.teaGreen.withOpacity(0.5 + scale * 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(_vm.dot1.value),
        const SizedBox(width: 6),
        dot(_vm.dot2.value),
        const SizedBox(width: 6),
        dot(_vm.dot3.value),
      ],
    );
  }
}

// ============================================================================
// BACKGROUND PATTERN PAINTER
// Subtle organic dot/circle pattern using brand palette
// ============================================================================

class BackgroundPatternPainter extends CustomPainter {
  final double pulse;
  BackgroundPatternPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // Large soft circles (background depth)
    _drawSoftCircle(canvas, Offset(size.width * 0.12, size.height * 0.18),
        size.width * 0.38, AppColors.celadon2.withOpacity(0.18 + pulse * 0.06));
    _drawSoftCircle(canvas, Offset(size.width * 0.88, size.height * 0.12),
        size.width * 0.30, AppColors.teaGreen.withOpacity(0.14 + pulse * 0.05));
    _drawSoftCircle(canvas, Offset(size.width * 0.75, size.height * 0.80),
        size.width * 0.42, AppColors.mutedTeal.withOpacity(0.12 + pulse * 0.04));
    _drawSoftCircle(canvas, Offset(size.width * 0.15, size.height * 0.72),
        size.width * 0.28, AppColors.dustyOlive2.withOpacity(0.10 + pulse * 0.04));

    // Subtle small dot pattern grid
    final dotPaint = Paint()
      ..color = AppColors.dustyOlive.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += 28) {
      for (double y = 0; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      }
    }
  }

  void _drawSoftCircle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(BackgroundPatternPainter old) => old.pulse != pulse;
}

// ============================================================================
// SCREEN TEXTURE PAINTER — Subtle inner glow + noise
// ============================================================================

class ScreenTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top glow vignette
    final topGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), topGlow);

    // Bottom gradient overlay
    final bottomGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          AppColors.celadon1.withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5), bottomGrad);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// DECORATIVE LEAF PAINTER
// Organic botanical illustration leaf
// ============================================================================

class DecorativeLeafPainter extends CustomPainter {
  final Color baseColor;
  final Color accentColor;
  const DecorativeLeafPainter({required this.baseColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Main leaf body
    final leafPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withOpacity(0.85),
          accentColor.withOpacity(0.65),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final leafPath = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 1.1, h * 0.2, w * 0.9, h * 0.8, w * 0.5, h)
      ..cubicTo(w * 0.1, h * 0.8, -w * 0.1, h * 0.2, w * 0.5, 0);

    canvas.drawPath(leafPath, leafPaint);

    // Midrib
    final ribPaint = Paint()
      ..color = baseColor.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.05), Offset(w * 0.5, h * 0.92), ribPaint);

    // Side veins
    final veinPaint = Paint()
      ..color = accentColor.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i <= 4; i++) {
      final y = h * (0.2 + i * 0.16);
      canvas.drawLine(
        Offset(w * 0.5, y),
        Offset(w * 0.2, y - h * 0.08),
        veinPaint,
      );
      canvas.drawLine(
        Offset(w * 0.5, y),
        Offset(w * 0.8, y - h * 0.08),
        veinPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC MILK CARTON PAINTER
// ============================================================================

class RealisticMilkCartonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ──────────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = AppColors.carbonBlack.withOpacity(0.28);
    canvas.drawOval(Rect.fromLTWH(w * 0.1, h * 0.88, w * 0.8, h * 0.14), shadowPaint);

    // ── Carton body ──────────────────────────────────────────────────────────
    final bodyGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFFF5F5F0),
          Color(0xFFFFFFFF),
          Color(0xFFE8E8E2),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.22, w, h * 0.78));

    final bodyPath = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.92, h * 0.90)
      ..quadraticBezierTo(w * 0.92, h * 0.96, w * 0.86, h * 0.96)
      ..lineTo(w * 0.14, h * 0.96)
      ..quadraticBezierTo(w * 0.08, h * 0.96, w * 0.08, h * 0.90)
      ..close();

    canvas.drawPath(bodyPath, bodyGrad);

    // Body outline
    final strokePaint = Paint()
      ..color = AppColors.charcoalBrown.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, strokePaint);

    // ── Gable top ────────────────────────────────────────────────────────────
    final topGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFF0F0EA), Color(0xFFE5E5DF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.30));

    // Front triangular fold
    final topFrontPath = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.92, h * 0.28)
      ..close();
    canvas.drawPath(topFrontPath, topGrad);
    canvas.drawPath(topFrontPath, strokePaint);

    // Top seam highlight
    final seamPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.38, h * 0.12), Offset(w * 0.62, h * 0.12), seamPaint);

    // ── Brand label area (green rectangle) ───────────────────────────────────
    final labelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [AppColors.mutedTeal, AppColors.dustyOlive],
      ).createShader(Rect.fromLTWH(w * 0.12, h * 0.38, w * 0.76, h * 0.30));

    final labelRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.38, w * 0.76, h * 0.30),
      const Radius.circular(4),
    );
    canvas.drawRRect(labelRRect, labelPaint);

    // Label text lines (simulated)
    final textLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.44, w * 0.56, h * 0.05), const Radius.circular(2)),
      textLinePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.51, w * 0.44, h * 0.04), const Radius.circular(2)),
      textLinePaint..color = Colors.white.withOpacity(0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.57, w * 0.52, h * 0.04), const Radius.circular(2)),
      textLinePaint,
    );

    // ── Milk wave illustration on lower carton ────────────────────────────────
    final wavePaint = Paint()
      ..color = const Color(0xFFEEF5FF).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final wavePath = Path()
      ..moveTo(w * 0.08, h * 0.80)
      ..quadraticBezierTo(w * 0.28, h * 0.74, w * 0.50, h * 0.78)
      ..quadraticBezierTo(w * 0.72, h * 0.82, w * 0.92, h * 0.76)
      ..lineTo(w * 0.92, h * 0.90)
      ..quadraticBezierTo(w * 0.92, h * 0.96, w * 0.86, h * 0.96)
      ..lineTo(w * 0.14, h * 0.96)
      ..quadraticBezierTo(w * 0.08, h * 0.96, w * 0.08, h * 0.90)
      ..close();
    canvas.drawPath(wavePath, wavePaint);

    // ── Highlight shine ───────────────────────────────────────────────────────
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(w * 0.14, h * 0.30, w * 0.22, h * 0.38))
      ..style = PaintingStyle.fill;
    final shinePath = Path()
      ..moveTo(w * 0.14, h * 0.32)
      ..quadraticBezierTo(w * 0.22, h * 0.30, w * 0.30, h * 0.36)
      ..lineTo(w * 0.26, h * 0.62)
      ..quadraticBezierTo(w * 0.18, h * 0.60, w * 0.14, h * 0.58)
      ..close();
    canvas.drawPath(shinePath, shinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC APPLE PAINTER
// ============================================================================

class RealisticApplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Drop shadow ───────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.86, w * 0.76, h * 0.16),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Apple body gradient ───────────────────────────────────────────────────
    final appleGrad = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors: const [
          Color(0xFFFF6B6B),
          Color(0xFFE53935),
          Color(0xFFB71C1C),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.08, w, h * 0.84));

    // Apple shape (two lobes with indent at top)
    final appleBody = Path();
    appleBody.moveTo(w * 0.50, h * 0.20);
    // Left lobe
    appleBody.cubicTo(w * 0.02, h * 0.20, w * 0.02, h * 0.58, w * 0.10, h * 0.72);
    appleBody.cubicTo(w * 0.18, h * 0.86, w * 0.32, h * 0.94, w * 0.50, h * 0.94);
    // Right lobe
    appleBody.cubicTo(w * 0.68, h * 0.94, w * 0.82, h * 0.86, w * 0.90, h * 0.72);
    appleBody.cubicTo(w * 0.98, h * 0.58, w * 0.98, h * 0.20, w * 0.50, h * 0.20);
    appleBody.close();

    canvas.drawPath(appleBody, appleGrad);

    // ── Stem ──────────────────────────────────────────────────────────────────
    final stemPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(w * 0.50, h * 0.20)
      ..quadraticBezierTo(w * 0.54, h * 0.04, w * 0.60, 0.0);
    canvas.drawPath(stemPath, stemPaint);

    // ── Leaf ──────────────────────────────────────────────────────────────────
    final leafGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: const [AppColors.dustyOlive, AppColors.teaGreen],
      ).createShader(Rect.fromLTWH(w * 0.50, 0, w * 0.42, h * 0.24));

    final leafPath = Path()
      ..moveTo(w * 0.55, h * 0.16)
      ..cubicTo(w * 0.68, h * 0.02, w * 0.92, h * 0.04, w * 0.88, h * 0.18)
      ..cubicTo(w * 0.84, h * 0.30, w * 0.64, h * 0.26, w * 0.55, h * 0.16);
    canvas.drawPath(leafPath, leafGrad);

    // Leaf midrib
    canvas.drawLine(
      Offset(w * 0.56, h * 0.17),
      Offset(w * 0.84, h * 0.14),
      Paint()
        ..color = AppColors.dustyOlive.withOpacity(0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Specular highlights ───────────────────────────────────────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.7,
        colors: [Colors.white.withOpacity(0.55), Colors.transparent],
      ).createShader(Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.36, h * 0.36));
    canvas.drawPath(appleBody, highlightPaint);

    // Small bright specular
    canvas.drawOval(
      Rect.fromLTWH(w * 0.14, h * 0.26, w * 0.18, h * 0.13),
      Paint()..color = Colors.white.withOpacity(0.45),
    );

    // ── Apple indent at top ───────────────────────────────────────────────────
    final indentPaint = Paint()
      ..color = const Color(0xFF9B0000).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.42, h * 0.17, w * 0.16, h * 0.07),
      indentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC CROISSANT PAINTER
// ============================================================================

class RealisticCroissantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.82, w * 0.80, h * 0.20),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Main crescent body ────────────────────────────────────────────────────
    final bodyGrad = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: const [
          Color(0xFFE8A04A),
          Color(0xFFCD7F32),
          Color(0xFF9B5E1A),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Crescent curve — main body
    final crescentPath = Path()
      ..moveTo(w * 0.02, h * 0.52)
      ..cubicTo(w * 0.00, h * 0.22, w * 0.22, h * 0.02, w * 0.50, h * 0.08)
      ..cubicTo(w * 0.78, h * 0.14, w * 1.00, h * 0.36, w * 0.98, h * 0.64)
      ..cubicTo(w * 0.96, h * 0.88, w * 0.72, h * 0.98, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.28, h * 0.82, w * 0.18, h * 0.72, w * 0.16, h * 0.72)
      ..cubicTo(w * 0.14, h * 0.68, w * 0.16, h * 0.60, w * 0.20, h * 0.60)
      ..cubicTo(w * 0.28, h * 0.60, w * 0.38, h * 0.68, w * 0.50, h * 0.72)
      ..cubicTo(w * 0.66, h * 0.76, w * 0.80, h * 0.68, w * 0.82, h * 0.56)
      ..cubicTo(w * 0.84, h * 0.44, w * 0.78, h * 0.32, w * 0.66, h * 0.28)
      ..cubicTo(w * 0.54, h * 0.24, w * 0.40, h * 0.30, w * 0.36, h * 0.40)
      ..cubicTo(w * 0.32, h * 0.50, w * 0.16, h * 0.62, w * 0.02, h * 0.52)
      ..close();

    canvas.drawPath(crescentPath, bodyGrad);

    // ── Layer flaking lines (realistic pastry layers) ─────────────────────────
    final layerPaint = Paint()
      ..color = const Color(0xFF7A4010).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Curved layer lines following the crescent shape
    for (int i = 1; i <= 5; i++) {
      final t = i / 6.0;
      final layerPath = Path()
        ..moveTo(w * (0.08 + t * 0.12), h * (0.46 - t * 0.08))
        ..quadraticBezierTo(
          w * (0.40 + t * 0.08),
          h * (0.14 + t * 0.06),
          w * (0.82 - t * 0.06),
          h * (0.46 + t * 0.06),
        );
      canvas.drawPath(layerPath, layerPaint);
    }

    // ── Top highlight ─────────────────────────────────────────────────────────
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.40),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5));
    canvas.drawPath(crescentPath, highlightPaint);

    // ── Glaze sheen (specular) ────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.28, h * 0.14, w * 0.32, h * 0.14),
      Paint()..color = Colors.white.withOpacity(0.28),
    );

    // ── Tip ends (darker baked tips) ─────────────────────────────────────────
    final tipPaint = Paint()..color = const Color(0xFF6B3510).withOpacity(0.50);
    canvas.drawOval(Rect.fromLTWH(w * 0.00, h * 0.42, w * 0.14, h * 0.18), tipPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.86, h * 0.46, w * 0.14, h * 0.22), tipPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC BREAD LOAF PAINTER
// ============================================================================

class RealisticBreadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.82, w * 0.88, h * 0.22),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // ── Loaf body ─────────────────────────────────────────────────────────────
    final loafGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFE8A855),
          Color(0xFFD4882A),
          Color(0xFFA85E18),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final loafPath = Path()
      ..moveTo(w * 0.06, h * 0.65)
      ..quadraticBezierTo(w * 0.06, h * 0.14, w * 0.18, h * 0.14)
      ..lineTo(w * 0.82, h * 0.14)
      ..quadraticBezierTo(w * 0.94, h * 0.14, w * 0.94, h * 0.65)
      ..lineTo(w * 0.94, h * 0.80)
      ..quadraticBezierTo(w * 0.94, h * 0.88, w * 0.86, h * 0.88)
      ..lineTo(w * 0.14, h * 0.88)
      ..quadraticBezierTo(w * 0.06, h * 0.88, w * 0.06, h * 0.80)
      ..close();

    // Top dome (bread rise)
    final domePath = Path()
      ..moveTo(w * 0.06, h * 0.58)
      ..cubicTo(w * 0.08, h * 0.06, w * 0.20, h * 0.02, w * 0.50, h * 0.02)
      ..cubicTo(w * 0.80, h * 0.02, w * 0.92, h * 0.06, w * 0.94, h * 0.58)
      ..close();

    canvas.drawPath(loafPath, loafGrad);
    canvas.drawPath(domePath, loafGrad);

    // ── Crust darker edge ──────────────────────────────────────────────────────
    final crustPaint = Paint()
      ..color = const Color(0xFF7A4010).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(loafPath, crustPaint);
    canvas.drawPath(domePath, crustPaint);

    // ── Slash scores on top ────────────────────────────────────────────────────
    final scorePaint = Paint()
      ..color = const Color(0xFF6B3510).withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    // 3 diagonal slash marks
    for (int i = 0; i < 3; i++) {
      final xBase = w * (0.25 + i * 0.20);
      canvas.drawLine(
        Offset(xBase - w * 0.06, h * 0.10),
        Offset(xBase + w * 0.06, h * 0.34),
        scorePaint,
      );
    }

    // ── Sesame seed decoration ────────────────────────────────────────────────
    final seedPaint = Paint()
      ..color = const Color(0xFFF5E6C8).withOpacity(0.80)
      ..style = PaintingStyle.fill;

    final seedPositions = [
      Offset(w * 0.20, h * 0.18), Offset(w * 0.34, h * 0.10),
      Offset(w * 0.50, h * 0.08), Offset(w * 0.65, h * 0.11),
      Offset(w * 0.78, h * 0.17), Offset(w * 0.28, h * 0.24),
      Offset(w * 0.58, h * 0.16), Offset(w * 0.72, h * 0.26),
    ];
    for (final pos in seedPositions) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(math.pi / 6);
      canvas.drawOval(Rect.fromLTWH(-4, -1.5, 8, 3), seedPaint);
      canvas.restore();
    }

    // ── Top highlight ──────────────────────────────────────────────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.1, -0.6),
        radius: 0.7,
        colors: [Colors.white.withOpacity(0.35), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(domePath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC BAGUETTE PAINTER
// ============================================================================

class RealisticBaguettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.05, h * 0.92, w * 0.90, h * 0.09),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Baguette body ─────────────────────────────────────────────────────────
    final baguetteGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFFC87A2A),
          Color(0xFFE8A855),
          Color(0xFFD4882A),
          Color(0xFF9B5E18),
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final bodyPath = Path()
      ..moveTo(w * 0.50, h * 0.01)
      ..cubicTo(w * 0.82, h * 0.01, w * 1.00, h * 0.04, w * 0.98, h * 0.10)
      ..lineTo(w * 0.98, h * 0.88)
      ..cubicTo(w * 0.98, h * 0.96, w * 0.78, h * 0.99, w * 0.50, h * 0.99)
      ..cubicTo(w * 0.22, h * 0.99, w * 0.02, h * 0.96, w * 0.02, h * 0.88)
      ..lineTo(w * 0.02, h * 0.10)
      ..cubicTo(w * 0.00, h * 0.04, w * 0.18, h * 0.01, w * 0.50, h * 0.01)
      ..close();

    canvas.drawPath(bodyPath, baguetteGrad);

    // ── Diagonal score marks ──────────────────────────────────────────────────
    final scorePaint = Paint()
      ..color = const Color(0xFF6B3510).withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // 5 diagonal slashes
    for (int i = 0; i < 5; i++) {
      final yBase = h * (0.14 + i * 0.155);
      canvas.drawLine(
        Offset(w * 0.12, yBase),
        Offset(w * 0.88, yBase + h * 0.06),
        scorePaint,
      );
    }

    // ── Crust shadow lines ─────────────────────────────────────────────────────
    final crustLinePaint = Paint()
      ..color = const Color(0xFF8B4010).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.15, h * 0.02), Offset(w * 0.15, h * 0.98), crustLinePaint);
    canvas.drawLine(Offset(w * 0.85, h * 0.02), Offset(w * 0.85, h * 0.98), crustLinePaint);

    // ── Specular highlight ─────────────────────────────────────────────────────
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.white.withOpacity(0.35), Colors.transparent],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, highlightPaint);

    // ── Ends (darker baked ends) ───────────────────────────────────────────────
    final endPaint = Paint()
      ..color = const Color(0xFF6B3010).withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(w * 0.10, h * 0.00, w * 0.80, h * 0.08), endPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.10, h * 0.92, w * 0.80, h * 0.08), endPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC TOMATO PAINTER
// ============================================================================

class RealisticTomatoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ─────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.10, h * 0.85, w * 0.80, h * 0.16),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Tomato body ────────────────────────────────────────────────────────
    final bodyGrad = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 0.88,
        colors: const [
          Color(0xFFFF8A65),
          Color(0xFFE53935),
          Color(0xFFC62828),
          Color(0xFF8E0000),
        ],
        stops: const [0.0, 0.40, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.10, w, h * 0.82));

    // Body shape — squashed sphere
    final bodyPath = Path()
      ..moveTo(w * 0.50, h * 0.16)
      ..cubicTo(w * 0.02, h * 0.16, w * 0.00, h * 0.45, w * 0.06, h * 0.66)
      ..cubicTo(w * 0.14, h * 0.88, w * 0.32, h * 0.96, w * 0.50, h * 0.96)
      ..cubicTo(w * 0.68, h * 0.96, w * 0.86, h * 0.88, w * 0.94, h * 0.66)
      ..cubicTo(w * 1.00, h * 0.45, w * 0.98, h * 0.16, w * 0.50, h * 0.16)
      ..close();

    canvas.drawPath(bodyPath, bodyGrad);

    // ── Tomato ridges (lobes) ──────────────────────────────────────────────
    final ridgePaint = Paint()
      ..color = const Color(0xFF8E0000).withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int i = 0; i < 4; i++) {
      final angle = (math.pi / 5) + i * (math.pi * 2 / 5);
      final cx = w * 0.50 + math.cos(angle) * w * 0.30;
      final cy = h * 0.56 + math.sin(angle) * h * 0.22;
      canvas.drawLine(Offset(w * 0.50, h * 0.20), Offset(cx, cy), ridgePaint);
    }

    // ── Calyx (green star on top) ──────────────────────────────────────────
    final calyxPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [AppColors.teaGreen, AppColors.dustyOlive],
      ).createShader(Rect.fromLTWH(w * 0.28, 0, w * 0.44, h * 0.22))
      ..style = PaintingStyle.fill;

    // 5 sepal petals
    for (int i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5) - math.pi / 2;
      final petalPath = Path();
      petalPath.moveTo(w * 0.50, h * 0.16);
      petalPath.quadraticBezierTo(
        w * 0.50 + math.cos(angle - 0.25) * w * 0.22,
        h * 0.16 + math.sin(angle - 0.25) * h * 0.18,
        w * 0.50 + math.cos(angle) * w * 0.28,
        h * 0.16 + math.sin(angle) * h * 0.22,
      );
      petalPath.quadraticBezierTo(
        w * 0.50 + math.cos(angle + 0.25) * w * 0.22,
        h * 0.16 + math.sin(angle + 0.25) * h * 0.18,
        w * 0.50,
        h * 0.16,
      );
      canvas.drawPath(petalPath, calyxPaint);
    }

    // Stem
    canvas.drawLine(
      Offset(w * 0.50, h * 0.10),
      Offset(w * 0.52, h * 0.00),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // ── Specular highlights ────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.24, h * 0.16),
      Paint()..color = Colors.white.withOpacity(0.40),
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.26, w * 0.12, h * 0.08),
      Paint()..color = Colors.white.withOpacity(0.60),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC BASKET PAINTER
// ============================================================================

class RealisticBasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shadow ─────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.05, h * 0.88, w * 0.90, h * 0.16),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Basket body gradient ───────────────────────────────────────────────
    final bodyGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF7DB88A),
          Color(0xFF5A8E6A),
          Color(0xFF3E6B4E),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Trapezoid body
    final bodyPath = Path()
      ..moveTo(w * 0.08, h * 0.04)
      ..lineTo(w * 0.92, h * 0.04)
      ..lineTo(w * 0.82, h * 0.78)
      ..quadraticBezierTo(w * 0.80, h * 0.88, w * 0.72, h * 0.90)
      ..quadraticBezierTo(w * 0.50, h * 0.96, w * 0.28, h * 0.90)
      ..quadraticBezierTo(w * 0.20, h * 0.88, w * 0.18, h * 0.78)
      ..close();

    canvas.drawPath(bodyPath, bodyGrad);

    // ── Weave pattern ──────────────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(bodyPath);

    // Horizontal weave bands
    final weaveLightPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final weaveDarkPaint = Paint()
      ..color = AppColors.carbonBlack.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int row = 0; row < 8; row++) {
      final y = h * (0.08 + row * 0.12);
      // Alternating horizontal stripes
      canvas.drawLine(Offset(w * 0.05, y), Offset(w * 0.95, y), weaveLightPaint);
      canvas.drawLine(Offset(w * 0.05, y + h * 0.05), Offset(w * 0.95, y + h * 0.05), weaveDarkPaint);
    }

    // Vertical slats
    final slatPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int col = 0; col < 9; col++) {
      final xRatio = 0.10 + col * 0.09;
      final xTop = w * xRatio;
      // Slats converge slightly toward basket bottom
      final xBot = w * (0.16 + col * 0.085);
      canvas.drawLine(Offset(xTop, h * 0.06), Offset(xBot, h * 0.86), slatPaint);
    }

    canvas.restore();

    // ── Rim at top ─────────────────────────────────────────────────────────
    final rimGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF8FC49A), Color(0xFF4A7A58)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.12));

    final rimPath = Path()
      ..moveTo(w * 0.04, h * 0.00)
      ..lineTo(w * 0.96, h * 0.00)
      ..lineTo(w * 0.92, h * 0.12)
      ..lineTo(w * 0.08, h * 0.12)
      ..close();

    canvas.drawPath(rimPath, rimGrad);

    // Rim highlight
    canvas.drawLine(
      Offset(w * 0.05, h * 0.02),
      Offset(w * 0.95, h * 0.02),
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..strokeWidth = 2.0,
    );

    // ── Basket outline ─────────────────────────────────────────────────────
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Handles ────────────────────────────────────────────────────────────
    final handlePaint = Paint()
      ..color = AppColors.charcoalBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    final handleHighlight = Paint()
      ..color = AppColors.mutedTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Left handle
    final leftHandle = Path()
      ..moveTo(w * 0.26, h * 0.04)
      ..cubicTo(w * 0.22, -h * 0.22, w * 0.40, -h * 0.36, w * 0.50, -h * 0.36);
    // Right handle
    final rightHandle = Path()
      ..moveTo(w * 0.74, h * 0.04)
      ..cubicTo(w * 0.78, -h * 0.22, w * 0.60, -h * 0.36, w * 0.50, -h * 0.36);

    canvas.drawPath(leftHandle, handlePaint);
    canvas.drawPath(rightHandle, handlePaint);
    canvas.drawPath(leftHandle, handleHighlight);
    canvas.drawPath(rightHandle, handleHighlight);

    // Handle end dots
    final dotPaint = Paint()..color = AppColors.charcoalBrown;
    canvas.drawCircle(Offset(w * 0.26, h * 0.04), 5, dotPaint);
    canvas.drawCircle(Offset(w * 0.74, h * 0.04), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// REALISTIC SCOOTER / DELIVERY BIKE PAINTER
// ============================================================================

class RealisticScooterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Ground shadow ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromLTWH(w * 0.05, h * 0.88, w * 0.90, h * 0.14),
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Rear wheel ────────────────────────────────────────────────────────
    _drawWheel(canvas, Offset(w * 0.20, h * 0.82), h * 0.16, w);

    // ── Front wheel ───────────────────────────────────────────────────────
    _drawWheel(canvas, Offset(w * 0.78, h * 0.82), h * 0.14, w);

    // ── Frame / Body ──────────────────────────────────────────────────────
    final bodyGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFF0F5F0),
          Color(0xFFD6E8D8),
          Color(0xFF8FA38A),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Main body silhouette
    final bodyPath = Path()
      ..moveTo(w * 0.12, h * 0.70)
      // Floor board
      ..lineTo(w * 0.68, h * 0.70)
      // Leg shield rise
      ..cubicTo(w * 0.72, h * 0.70, w * 0.76, h * 0.66, w * 0.80, h * 0.60)
      // Front fork
      ..lineTo(w * 0.80, h * 0.44)
      ..lineTo(w * 0.76, h * 0.40)
      // Handlebars curve
      ..lineTo(w * 0.72, h * 0.30)
      ..cubicTo(w * 0.70, h * 0.24, w * 0.60, h * 0.22, w * 0.56, h * 0.26)
      // Seat
      ..cubicTo(w * 0.52, h * 0.30, w * 0.50, h * 0.34, w * 0.44, h * 0.34)
      ..cubicTo(w * 0.38, h * 0.34, w * 0.24, h * 0.38, w * 0.22, h * 0.50)
      // Rear chassis
      ..lineTo(w * 0.12, h * 0.62)
      ..close();

    canvas.drawPath(bodyPath, bodyGrad);

    // Body outline
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Seat ──────────────────────────────────────────────────────────────
    final seatGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF4A5548), AppColors.carbonBlack],
      ).createShader(Rect.fromLTWH(w * 0.36, h * 0.26, w * 0.22, h * 0.14));

    final seatPath = Path()
      ..moveTo(w * 0.36, h * 0.32)
      ..cubicTo(w * 0.36, h * 0.26, w * 0.40, h * 0.26, w * 0.48, h * 0.26)
      ..cubicTo(w * 0.56, h * 0.26, w * 0.58, h * 0.30, w * 0.58, h * 0.34)
      ..cubicTo(w * 0.58, h * 0.38, w * 0.52, h * 0.38, w * 0.44, h * 0.38)
      ..cubicTo(w * 0.36, h * 0.38, w * 0.36, h * 0.36, w * 0.36, h * 0.32)
      ..close();

    canvas.drawPath(seatPath, seatGrad);
    canvas.drawLine(
      Offset(w * 0.38, h * 0.30),
      Offset(w * 0.56, h * 0.30),
      Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 2.0..style = PaintingStyle.stroke,
    );

    // ── Headlight ─────────────────────────────────────────────────────────
    final headlightPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.fill;
    final headlightGlow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF9C4), Colors.transparent],
      ).createShader(Rect.fromLTWH(w * 0.74, h * 0.34, w * 0.10, h * 0.10));

    canvas.drawOval(Rect.fromLTWH(w * 0.74, h * 0.36, w * 0.09, h * 0.08), headlightPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.70, h * 0.32, w * 0.18, h * 0.16), headlightGlow);

    // Headlight border
    canvas.drawOval(
      Rect.fromLTWH(w * 0.74, h * 0.36, w * 0.09, h * 0.08),
      Paint()
        ..color = AppColors.carbonBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // ── Delivery Box ─────────────────────────────────────────────────────
    final boxGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          AppColors.dustyOlive,
          AppColors.charcoalBrown,
          AppColors.carbonBlack,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.36, h * 0.46));

    // Box body
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.32, h * 0.42),
      const Radius.circular(6),
    );
    canvas.drawRRect(boxRect, boxGrad);

    // Box top face (isometric look)
    final topFaceGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [AppColors.mutedTeal, AppColors.dustyOlive],
      ).createShader(Rect.fromLTWH(w * 0.14, h * 0.10, w * 0.36, h * 0.10));

    final topFacePath = Path()
      ..moveTo(w * 0.14, h * 0.18)
      ..lineTo(w * 0.20, h * 0.10)
      ..lineTo(w * 0.52, h * 0.10)
      ..lineTo(w * 0.46, h * 0.18)
      ..close();
    canvas.drawPath(topFacePath, topFaceGrad);

    // Box right face
    final rightFaceGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [AppColors.charcoalBrown, AppColors.black],
      ).createShader(Rect.fromLTWH(w * 0.46, h * 0.10, w * 0.08, h * 0.50));

    final rightFacePath = Path()
      ..moveTo(w * 0.46, h * 0.18)
      ..lineTo(w * 0.52, h * 0.10)
      ..lineTo(w * 0.52, h * 0.56)
      ..lineTo(w * 0.46, h * 0.60)
      ..close();
    canvas.drawPath(rightFacePath, rightFaceGrad);

    // Box highlight stripe
    canvas.drawLine(
      Offset(w * 0.18, h * 0.22),
      Offset(w * 0.18, h * 0.56),
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Box brand text lines (simulated)
    final boxTextPaint = Paint()
      ..color = AppColors.teaGreen.withOpacity(0.60)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.28, w * 0.20, h * 0.04), const Radius.circular(2)),
      boxTextPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.34, w * 0.14, h * 0.03), const Radius.circular(2)),
      boxTextPaint..color = AppColors.celadon1.withOpacity(0.50),
    );

    // MV leaf logo on box
    canvas.drawCircle(
      Offset(w * 0.30, h * 0.46),
      w * 0.06,
      Paint()..color = AppColors.teaGreen.withOpacity(0.30),
    );
    canvas.drawCircle(
      Offset(w * 0.30, h * 0.46),
      w * 0.06,
      Paint()
        ..color = AppColors.teaGreen.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Box outline
    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawPath(
      topFacePath,
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      rightFacePath,
      Paint()
        ..color = AppColors.carbonBlack.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Exhaust pipe ──────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(w * 0.12, h * 0.66),
      Offset(w * 0.04, h * 0.72),
      Paint()
        ..color = AppColors.charcoalBrown
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    // ── Handlebar ─────────────────────────────────────────────────────────
    final handlebarPaint = Paint()
      ..color = AppColors.carbonBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.68, h * 0.26), Offset(w * 0.78, h * 0.28), handlebarPaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.26), Offset(w * 0.70, h * 0.20), handlebarPaint);
    canvas.drawLine(Offset(w * 0.76, h * 0.28), Offset(w * 0.76, h * 0.22), handlebarPaint);

    // Grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.18, w * 0.04, h * 0.06),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.carbonBlack,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.73, h * 0.20, w * 0.04, h * 0.06),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.carbonBlack,
    );

    // ── Body highlight ─────────────────────────────────────────────────────
    final bodyHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.32), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.6, h * 0.6));
    canvas.drawPath(bodyPath, bodyHighlight);
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, double w) {
    // Tire (outer dark ring)
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.carbonBlack,
    );
    // Tire highlight
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22,
    );
    // Hub
    canvas.drawCircle(
      center,
      radius * 0.50,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFBDBDBD), Color(0xFF757575)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.50)),
    );
    // Spokes
    final spokePaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 1.8;
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * radius * 0.18, center.dy + math.sin(angle) * radius * 0.18),
        Offset(center.dx + math.cos(angle) * radius * 0.46, center.dy + math.sin(angle) * radius * 0.46),
        spokePaint,
      );
    }
    // Center cap
    canvas.drawCircle(center, radius * 0.12, Paint()..color = const Color(0xFFE0E0E0));
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = AppColors.carbonBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}