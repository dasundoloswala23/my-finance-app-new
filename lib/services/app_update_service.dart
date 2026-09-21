import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play Store in-app updates.
///
/// This only does anything on Android, and only for builds that were actually
/// installed from the Play Store. Any local debug or sideloaded build throws,
/// so every call here is guarded.
class AppUpdateService {
  const AppUpdateService._();

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Checks for an available update and, if one is found, runs the flexible
  /// update flow. Returns true when an update was started.
  static Future<bool> checkForUpdate() async {
    if (!_isSupported) return false;

    try {
      final info = await InAppUpdate.checkForUpdate();

      // An immediate update the developer triggered earlier was interrupted —
      // resume it before anything else.
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      return false;
    } catch (error) {
      // Not installed from Play, no network, or the user dismissed the flow.
      debugPrint('In-app update unavailable: $error');
      return false;
    }
  }

  /// Forces the blocking update flow. Use this when a version is unusable and
  /// the user must update before continuing.
  static Future<bool> performImmediateUpdate() async {
    if (!_isSupported) return false;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.immediateUpdateAllowed) {
        return false;
      }
      await InAppUpdate.performImmediateUpdate();
      return true;
    } catch (error) {
      debugPrint('Immediate update unavailable: $error');
      return false;
    }
  }
}
