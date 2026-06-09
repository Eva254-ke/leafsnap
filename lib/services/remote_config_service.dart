import 'dart:convert';
import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);
  StreamSubscription<RemoteConfigUpdate>? _realtimeSubscription;
  bool _isRefreshing = false;

  Future<void> init() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? const Duration(minutes: 1) : const Duration(minutes: 30),
      ),
    );
    await _remoteConfig.setDefaults(_defaults);
    await _remoteConfig.fetchAndActivate();
    _listenForRealtimeUpdates();
    _bumpRefresh();
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      await _remoteConfig.fetchAndActivate();
      _bumpRefresh();
    } catch (_) {
      // Keep the app usable with the last activated/default config.
    } finally {
      _isRefreshing = false;
    }
  }

  String getString(String key) => _remoteConfig.getString(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);

  Map<String, dynamic> getJson(String key) {
    final raw = _remoteConfig.getString(key).trim();
    if (raw.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return const {};
    }

    return const {};
  }

  void _bumpRefresh() {
    refreshSignal.value = refreshSignal.value + 1;
  }

  void _listenForRealtimeUpdates() {
    if (kIsWeb || _realtimeSubscription != null) {
      return;
    }

    _realtimeSubscription = _remoteConfig.onConfigUpdated.listen((_) async {
      try {
        final activated = await _remoteConfig.activate();
        if (activated) {
          _bumpRefresh();
        }
      } catch (_) {
        // Startup/resume refresh still covers the fallback path.
      }
    });
  }

  static const Map<String, Object> _defaults = {
    RemoteConfigKeys.maintenanceMode: false,
    RemoteConfigKeys.maintenanceMessage:
        'We are tuning LeafSnap right now. Please check back shortly.',
    RemoteConfigKeys.forceUpdateMinBuild: 1,
    RemoteConfigKeys.forceUpdateUrl:
        'https://play.google.com/store/apps/details?id=com.leafsnap.ai',
    RemoteConfigKeys.appBannerEnabled: false,
    RemoteConfigKeys.appBannerMessage: 'New plant packs are now available.',
    RemoteConfigKeys.appBannerTone: 'info',
    RemoteConfigKeys.homeBannerEnabled: false,
    RemoteConfigKeys.homeBannerMessage:
        'Tip: Scan leaves in natural light for the best matches.',
    RemoteConfigKeys.screenBanners: '{}',
    RemoteConfigKeys.screenThemeColors: '{}',
    RemoteConfigKeys.privacyPolicyUrl: 'https://leafsnap.app/privacy',
    RemoteConfigKeys.termsOfUseUrl: 'https://leafsnap.app/terms',
    RemoteConfigKeys.helpUrl: 'https://leafsnap.app/help',
    RemoteConfigKeys.supportEmail: 'support@leafsnap.app',
    RemoteConfigKeys.supportSubject: 'LeafSnap Support Request',
    RemoteConfigKeys.supportBody: 'Describe your issue here:\n\n',
    RemoteConfigKeys.iosStoreUrl:
        'https://apps.apple.com/app/leafsnap/id123456789',
    RemoteConfigKeys.androidStoreUrl:
        'https://play.google.com/store/apps/details?id=com.example.leafsnap_ai',
    RemoteConfigKeys.shareUrl:
        'https://play.google.com/store/apps/details?id=com.example.leafsnap_ai',
    RemoteConfigKeys.androidMonthlyProductId: 'leafsnap_premium_monthly',
    RemoteConfigKeys.androidYearlyProductId: 'leafsnap_premium_yearly',
    RemoteConfigKeys.qaScanResetEnabled: false,
    RemoteConfigKeys.backendBaseUrl: 'https://leafsnap-api.cloubridge.com',
    RemoteConfigKeys.featureCameraEnabled: true,
    RemoteConfigKeys.featureDiagnoseEnabled: true,
    RemoteConfigKeys.onboardingCopy:
        '{"screen1_title":"The magic of nature\\nat your fingertips","screen1_subtitle":"Identify any plant instantly\\nwith 99.9% accuracy","screen1_cta":"Continue","screen1_terms":"By tapping Continue, you agree to our Terms of Use\\nand Privacy Policy.","scene1_eyebrow":"Discover","scene1_title":"Every leaf tells\\na story","scene1_subtitle":"Point your camera and unlock the secrets of thousands of plants.","scene2_eyebrow":"Learn","scene2_title":"From curious\\nto expert","scene2_subtitle":"Identify trees, flowers, succulents, and more with confidence.","scene3_eyebrow":"Nurture","scene3_title":"Give every plant\\nthe care it needs","scene3_subtitle":"Personalized watering, light, and care advice for a thriving garden."}',
  };
}

class RemoteConfigKeys {
  static const maintenanceMode = 'maintenance_mode';
  static const maintenanceMessage = 'maintenance_message';
  static const forceUpdateMinBuild = 'force_update_min_build';
  static const forceUpdateUrl = 'force_update_url';
  static const appBannerEnabled = 'app_banner_enabled';
  static const appBannerMessage = 'app_banner_message';
  static const appBannerTone = 'app_banner_tone';
  static const homeBannerEnabled = 'home_banner_enabled';
  static const homeBannerMessage = 'home_banner_message';
  static const screenBanners = 'screen_banners';
  static const screenThemeColors = 'screen_theme_colors';
  static const privacyPolicyUrl = 'privacy_policy_url';
  static const termsOfUseUrl = 'terms_of_use_url';
  static const helpUrl = 'help_url';
  static const supportEmail = 'support_email';
  static const supportSubject = 'support_subject';
  static const supportBody = 'support_body';
  static const iosStoreUrl = 'ios_store_url';
  static const androidStoreUrl = 'android_store_url';
  static const shareUrl = 'share_url';
  static const androidMonthlyProductId = 'android_monthly_product_id';
  static const androidYearlyProductId = 'android_yearly_product_id';
  static const qaScanResetEnabled = 'qa_scan_reset_enabled';
  static const backendBaseUrl = 'backend_base_url';
  static const featureCameraEnabled = 'feature_camera_enabled';
  static const featureDiagnoseEnabled = 'feature_diagnose_enabled';
  static const onboardingCopy = 'onboarding_copy';
}
