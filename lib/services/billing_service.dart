import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart'; // removed – widgets.dart already provides needed symbols
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  static const String entitlementId = 'Leafsnap AI Pro';
  // Tracks whether Purchases.configure succeeded
  static bool _isConfigured = false;
  // Public accessor for other parts of the app
  static bool get isConfigured => _isConfigured;

  // Retrieve RevenueCat API keys from .env. If the key is missing or still the test placeholder, we log a warning.
  static String get revenueCatApiKeyApple {
    final key = dotenv.env['REVENUECAT_APPLE_KEY'];
    assert(key != null && key.isNotEmpty && !key.startsWith('test_'),
        'Missing or placeholder REVENUECAT_APPLE_KEY. Add a valid key to .env');
    return key ?? '';
  }

  static String get revenueCatApiKeyGoogle {
    final key = dotenv.env['REVENUECAT_GOOGLE_KEY'];
    assert(key != null && key.isNotEmpty && !key.startsWith('test_'),
        'Missing or placeholder REVENUECAT_GOOGLE_KEY. Add a valid key to .env');
    return key ?? '';
  }

  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    // Configure RevenueCat only when a valid API key is present.
    if (Platform.isAndroid) {
      if (revenueCatApiKeyGoogle.isNotEmpty) {
        configuration = PurchasesConfiguration(revenueCatApiKeyGoogle);
      } else {
        debugPrint('⚠️ RevenueCat Google API key missing – paywall disabled');
      }
    } else if (Platform.isIOS) {
      if (revenueCatApiKeyApple.isNotEmpty) {
        configuration = PurchasesConfiguration(revenueCatApiKeyApple);
      } else {
        debugPrint('⚠️ RevenueCat Apple API key missing – paywall disabled');
      }
    } else if (Platform.isMacOS) {
      if (revenueCatApiKeyApple.isNotEmpty) {
        configuration = PurchasesConfiguration(revenueCatApiKeyApple);
      } else {
        debugPrint('⚠️ RevenueCat Apple API key missing – paywall disabled');
      }
    }

    if (configuration != null) {
      try {
        await Purchases.configure(configuration);
        // Mark configuration as successful so UI can safely call RevenueCatUI
        _isConfigured = true;
      } catch (e) {
        debugPrint('RevenueCat configuration error (code 23?): $e');
        _isConfigured = false;
      }

      if (_isConfigured) {
        _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
          if (user != null) {
            try {
              await Purchases.logIn(user.uid);
            } catch (e) {
              debugPrint('RevenueCat login error: $e');
            }
          } else {
            try {
              await Purchases.logOut();
            } catch (e) {
              debugPrint('RevenueCat logout error: $e');
            }
          }
          await _checkEntitlements();
        });

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      await _checkEntitlements();
    }
  }
}
  Future<void> _checkEntitlements() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      debugPrint('Failed to get customer info: $e');
      isPremium.value = false;
    }
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) {
    if (customerInfo.entitlements.all[entitlementId] != null &&
        customerInfo.entitlements.all[entitlementId]!.isActive) {
      isPremium.value = true;
    } else {
      isPremium.value = false;
    }
  }

  Future<void> presentPaywall() async {
    if (!_isConfigured) {
      debugPrint('⚠️ RevenueCat not configured – paywall suppressed');
      return;
    }
    // Defer the UI presentation until the next frame to ensure the view has a
    // valid size. This mitigates the AndroidComposeView "setRequestedFrameRate"
    // NaN warnings that appear when the view is measured as 0×0.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
          entitlementId,
        );
        debugPrint('Paywall result: $paywallResult');
      } catch (e) {
        debugPrint('Error presenting paywall: $e');
      }
    });
  }



  Future<void> presentCustomerCenter() async {
    try {
      if (Platform.isIOS) {
        // Customer Center is currently iOS only in most versions, but RevenueCatUI handles it if supported
        await RevenueCatUI.presentCustomerCenter();
      } else {
        debugPrint('Customer Center is primarily supported on iOS.');
      }
    } on PlatformException catch (e) {
      debugPrint('Error presenting Customer Center: ${e.message}');
    } catch (e) {
      debugPrint('Error presenting Customer Center: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }
}
