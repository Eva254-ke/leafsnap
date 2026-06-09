import 'package:flutter/material.dart';

import '../services/remote_config_service.dart';

class RemoteConfigScreens {
  const RemoteConfigScreens._();

  static const home = 'home';
  static const diagnose = 'diagnose';
  static const myPlants = 'my_plants';
  static const more = 'more';
  static const settings = 'settings';
  static const plantResult = 'plant_result';
}

class RemoteScreenConfig {
  const RemoteScreenConfig({
    required this.backgroundColor,
    required this.primaryColor,
    required this.banner,
  });

  final Color backgroundColor;
  final Color primaryColor;
  final RemoteScreenBannerData? banner;

  static RemoteScreenConfig resolve({
    required String screenId,
    required Color fallbackBackgroundColor,
    required Color fallbackPrimaryColor,
  }) {
    final rc = RemoteConfigService.instance;
    final theme = rc.getJson(RemoteConfigKeys.screenThemeColors);
    final themeForScreen = _mapAt(theme, screenId);

    return RemoteScreenConfig(
      backgroundColor: _colorAt(
        themeForScreen,
        'background',
        fallbackBackgroundColor,
      ),
      primaryColor: _colorAt(themeForScreen, 'primary', fallbackPrimaryColor),
      banner: RemoteScreenBannerData.resolve(screenId),
    );
  }

  static Map<String, dynamic> _mapAt(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value is Map<String, dynamic> ? value : const {};
  }

  static Color _colorAt(
    Map<String, dynamic> map,
    String key,
    Color fallback,
  ) {
    final value = map[key];
    if (value is! String) {
      return fallback;
    }
    return parseRemoteColor(value) ?? fallback;
  }
}

class RemoteScreenBannerData {
  const RemoteScreenBannerData({
    required this.message,
    required this.tone,
  });

  final String message;
  final String tone;

  static RemoteScreenBannerData? resolve(String screenId) {
    final rc = RemoteConfigService.instance;
    final banners = rc.getJson(RemoteConfigKeys.screenBanners);
    final raw = banners[screenId];

    if (raw is Map<String, dynamic>) {
      final enabled = raw['enabled'] == true;
      final message = (raw['message'] ?? '').toString().trim();
      final tone = (raw['tone'] ?? 'info').toString().trim();
      if (enabled && message.isNotEmpty) {
        return RemoteScreenBannerData(message: message, tone: tone);
      }
    }

    if (screenId == RemoteConfigScreens.home &&
        rc.getBool(RemoteConfigKeys.homeBannerEnabled)) {
      final message = rc.getString(RemoteConfigKeys.homeBannerMessage).trim();
      if (message.isNotEmpty) {
        return RemoteScreenBannerData(message: message, tone: 'success');
      }
    }

    return null;
  }
}

class RemoteConfigBuilder extends StatelessWidget {
  const RemoteConfigBuilder({
    super.key,
    required this.screenId,
    required this.fallbackBackgroundColor,
    required this.fallbackPrimaryColor,
    required this.builder,
  });

  final String screenId;
  final Color fallbackBackgroundColor;
  final Color fallbackPrimaryColor;
  final Widget Function(BuildContext context, RemoteScreenConfig config) builder;

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.instance;
    return ValueListenableBuilder<int>(
      valueListenable: rc.refreshSignal,
      builder: (context, _, __) {
        return builder(
          context,
          RemoteScreenConfig.resolve(
            screenId: screenId,
            fallbackBackgroundColor: fallbackBackgroundColor,
            fallbackPrimaryColor: fallbackPrimaryColor,
          ),
        );
      },
    );
  }
}

class RemoteScreenBanner extends StatelessWidget {
  const RemoteScreenBanner({
    super.key,
    required this.banner,
    required this.primaryColor,
  });

  final RemoteScreenBannerData banner;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(banner.tone, primaryColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(colors.icon, size: 18, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              banner.message,
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _RemoteBannerColors _colorsForTone(String tone, Color primaryColor) {
    switch (tone.toLowerCase()) {
      case 'warning':
        return const _RemoteBannerColors(
          background: Color(0xFFFFF7E6),
          border: Color(0xFFF2D28C),
          foreground: Color(0xFF6C4D00),
          icon: Icons.info_outline,
        );
      case 'error':
        return const _RemoteBannerColors(
          background: Color(0xFFFFEFEF),
          border: Color(0xFFF2C4C4),
          foreground: Color(0xFF8F2E2E),
          icon: Icons.error_outline,
        );
      case 'success':
        return const _RemoteBannerColors(
          background: Color(0xFFE8F7EE),
          border: Color(0xFFBFE8CD),
          foreground: Color(0xFF135B2C),
          icon: Icons.check_circle_outline,
        );
      default:
        return _RemoteBannerColors(
          background: primaryColor.withValues(alpha: 0.1),
          border: primaryColor.withValues(alpha: 0.22),
          foreground: primaryColor,
          icon: Icons.campaign_outlined,
        );
    }
  }
}

class _RemoteBannerColors {
  const _RemoteBannerColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}

Color? parseRemoteColor(String raw) {
  var normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.startsWith('#')) {
    normalized = normalized.substring(1);
  } else if (normalized.startsWith('0x')) {
    normalized = normalized.substring(2);
  }

  if (normalized.length == 6) {
    normalized = 'FF$normalized';
  }
  if (normalized.length != 8) {
    return null;
  }

  final value = int.tryParse(normalized, radix: 16);
  return value == null ? null : Color(value);
}
