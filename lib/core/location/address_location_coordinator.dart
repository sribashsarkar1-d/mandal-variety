import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../common/dialogs/app_dialog.dart';
import '../../common/snackbars/app_snackbar.dart';
import '../../data/models/address_models.dart';
import '../../data/repositories/address_repository.dart';
import 'device_location_service.dart';

class AddressLocationCoordinator {
  static final AddressLocationCoordinator instance =
      AddressLocationCoordinator._();

  final AddressRepository _repo = AddressRepository();
  final DeviceLocationService _device = const DeviceLocationService();

  bool _initialized = false;

  AddressLocationCoordinator._();

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await _repo.init();
    _initialized = true;
  }

  Future<AddressCache> getCache() => _repo.getCache();

  Future<void> setSelectedAddressId(String id) =>
      _repo.setSelectedAddressId(id);

  Future<void> upsertManualAddress(ManualAddress address) =>
      _repo.upsertManualAddress(address);

  Future<void> deleteManualAddress(String id) => _repo.deleteManualAddress(id);

  /// Called from app startup after first frame.
  ///
  /// - On first install, requests permission and caches the initial detected location.
  /// - If services are off, prompts the user to enable them.
  Future<void> ensureFirstInstallDetection(
    BuildContext context, {
    bool requestPermissionIfNeeded = true,
  }) async {
    await init();
    if (_repo.isFirstInstallCompleted) return;

    try {
      await _detectAndCache(
        context: context,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
        showBlockingPrompts: true,
        replaceOnlyIfMoved: false,
      );
    } finally {
      // Mark completion even if user denies; we won't keep prompting at startup.
      await _repo.setFirstInstallCompleted(true);
    }
  }

  /// Called when the app is opened/resumed.
  ///
  /// Attempts to refresh cached coordinates if permission/services allow.
  /// Does not show blocking prompts.
  Future<void> syncOnAppOpen() async {
    await init();
    await _detectAndCache(
      context: null,
      requestPermissionIfNeeded: false,
      showBlockingPrompts: false,
      replaceOnlyIfMoved: true,
    );
  }

  /// Same as [syncOnAppOpen], but can show prompts if location services are off
  /// (or permission is permanently denied).
  Future<void> syncOnAppOpenWithPrompts(BuildContext context) async {
    await init();
    await _detectAndCache(
      context: context,
      requestPermissionIfNeeded: false,
      showBlockingPrompts: true,
      replaceOnlyIfMoved: true,
    );
  }

  Future<void> locateMeAgain(BuildContext context) async {
    await init();
    final success = await _detectAndCache(
      context: context,
      requestPermissionIfNeeded: true,
      showBlockingPrompts: true,
      replaceOnlyIfMoved: false,
    );

    if (success && context.mounted) {
      AppSnackbar.success(context, 'Location updated');
    }
  }

  Future<bool> _detectAndCache({
    required BuildContext? context,
    required bool requestPermissionIfNeeded,
    required bool showBlockingPrompts,
    required bool replaceOnlyIfMoved,
  }) async {
    try {
      final snapshot = await _device.getCurrentLocationSnapshot(
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      );

      if (replaceOnlyIfMoved) {
        final cache = await _repo.getCache();
        final old = cache.autoLocation;
        if (old != null) {
          final meters = Geolocator.distanceBetween(
            old.latitude,
            old.longitude,
            snapshot.latitude,
            snapshot.longitude,
          );

          // Avoid noise — only replace if user has actually moved.
          if (meters < 80) return true;
        }
      }

      await _repo.saveAutoLocation(snapshot);
      final cache = await _repo.getCache();
      final selected = cache.selectedAddressId;
      if (selected.isEmpty || selected == AddressRepositoryKeys.autoId) {
        await _repo.setSelectedAddressId(AddressRepositoryKeys.autoId);
      }
      return true;
    } on LocationException catch (e) {
      if (!showBlockingPrompts || context == null) return false;

      switch (e.code) {
        case LocationException.serviceDisabled:
          await _promptEnableLocationServices(context);
          return false;
        case LocationException.permissionDeniedForever:
          await _promptOpenAppSettings(context);
          return false;
        case LocationException.permissionDenied:
          if (requestPermissionIfNeeded && context.mounted) {
            AppSnackbar.warning(
              context,
              'Location permission denied. You can add an address manually.',
            );
          }
          return false;
        default:
          if (context.mounted) {
            AppSnackbar.error(context, 'Could not detect location');
          }
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _promptEnableLocationServices(BuildContext context) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Enable Location',
      message:
          'Location services are turned off. Please enable them to detect your current address.',
      confirmText: 'Open Settings',
      cancelText: 'Not Now',
    );

    if (confirmed == true) {
      await Geolocator.openLocationSettings();
    }
  }

  Future<void> _promptOpenAppSettings(BuildContext context) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Permission Required',
      message:
          'Location permission is permanently denied. Please enable it from app settings to use automatic detection.',
      confirmText: 'Open Settings',
      cancelText: 'Not Now',
    );

    if (confirmed == true) {
      await Geolocator.openAppSettings();
    }
  }
}
