import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'core/cart/cart_coordinator.dart';
import 'core/background/app_background_coordinator.dart';
import 'core/tobacco/tobacco_access_coordinator.dart';
import 'core/theme/app_theme.dart';
import 'core/responsive/media_query_helper.dart';
import 'core/location/address_location_coordinator.dart';
import 'core/permissions/app_permission_coordinator.dart';
import 'core/wishlist/wishlist_coordinator.dart';
import 'services/session_service.dart';
import 'views/splash/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SessionService.instance.loadSessionOnAppStart();
  await CartCoordinator.instance.init();
  await WishlistCoordinator.instance.init();
  await AddressLocationCoordinator.instance.init();
  await TobaccoAccessCoordinator.instance.init();
  await AppBackgroundCoordinator.instance.init();

  runApp(
    DevicePreview(
      // enabled: true,
      enabled: false,
      builder: (context) => const EnchantedForestApp(),
    ),
  );
}

class EnchantedForestApp extends StatefulWidget {
  const EnchantedForestApp({super.key});

  @override
  State<EnchantedForestApp> createState() => _EnchantedForestAppState();
}

class _EnchantedForestAppState extends State<EnchantedForestApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb || !mounted) return;

      await AppPermissionCoordinator.instance.requestPermissionsOnFirstLaunch(
        context,
      );
      await AddressLocationCoordinator.instance.ensureFirstInstallDetection(
        context,
        requestPermissionIfNeeded: false,
      );
      await AddressLocationCoordinator.instance.syncOnAppOpenWithPrompts(
        context,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kIsWeb) return;
      if (!mounted) return;
      AddressLocationCoordinator.instance.syncOnAppOpenWithPrompts(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsive MediaQuery logic right at root level context
    // before initializing Theme which uses AppTextStyles relying on MediaQueryHelper
    MediaQueryHelper.init(context);

    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        final devicePreviewChild = DevicePreview.appBuilder(context, child);
        return ValueListenableBuilder<String?>(
          valueListenable: AppBackgroundCoordinator.instance.backgroundUrl,
          builder: (context, backgroundUrl, _) {
            if (backgroundUrl == null || backgroundUrl.isEmpty) {
              return devicePreviewChild;
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: backgroundUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: devicePreviewChild,
                ),
              ],
            );
          },
        );
      },
      title: 'Enchanted Forest App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          ThemeMode.system, // Supports both dark and light modes automatically
      home: const SplashScreen(),
    );
  }
}
