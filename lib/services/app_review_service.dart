import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Store review prompts.
///
/// [requestReview] shows the native in-app review sheet. The OS decides whether
/// to actually display it and silently ignores the request when it has been
/// shown too recently, so it must never be the only way to leave a review —
/// [openStoreListing] is the explicit "Rate this app" path.
class AppReviewService {
  const AppReviewService._();

  /// App Store Connect numeric app ID, needed to open the iOS store listing.
  /// Not yet assigned — the app has not been created in App Store Connect.
  static const String? _appStoreId = null;

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Asks the OS to show the in-app review sheet. Returns true if the request
  /// was made; the sheet itself may still not appear.
  static Future<bool> requestReview() async {
    try {
      if (!await _inAppReview.isAvailable()) return false;
      await _inAppReview.requestReview();
      return true;
    } catch (error) {
      debugPrint('In-app review unavailable: $error');
      return false;
    }
  }

  /// Opens the Play Store / App Store listing so the user can review manually.
  static Future<bool> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(appStoreId: _appStoreId);
      return true;
    } catch (error) {
      debugPrint('Could not open store listing: $error');
      return false;
    }
  }

  /// Tries the native sheet first and falls back to the store listing, so the
  /// user always ends up somewhere they can leave a review.
  static Future<void> rateApp() async {
    if (await requestReview()) return;
    await openStoreListing();
  }
}
