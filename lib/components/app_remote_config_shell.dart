import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/remote_config_service.dart';

class AppRemoteConfigShell extends StatefulWidget {
  const AppRemoteConfigShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppRemoteConfigShell> createState() => _AppRemoteConfigShellState();
}

class _AppRemoteConfigShellState extends State<AppRemoteConfigShell> {
  int? _buildNumber;

  @override
  void initState() {
    super.initState();
    _loadBuildNumber();
  }

  Future<void> _loadBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    final parsed = int.tryParse(info.buildNumber);
    if (mounted) {
      setState(() {
        _buildNumber = parsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.instance;

    return ValueListenableBuilder<int>(
      valueListenable: rc.refreshSignal,
      builder: (context, _, __) {
        final maintenanceMode = rc.getBool(RemoteConfigKeys.maintenanceMode);
        final maintenanceMessage = rc
            .getString(RemoteConfigKeys.maintenanceMessage)
            .trim();
        final minBuild = rc.getInt(RemoteConfigKeys.forceUpdateMinBuild);
        final updateUrl = rc.getString(RemoteConfigKeys.forceUpdateUrl).trim();
        final appBannerEnabled =
            rc.getBool(RemoteConfigKeys.appBannerEnabled);
        final appBannerMessage =
            rc.getString(RemoteConfigKeys.appBannerMessage).trim();
        final appBannerTone =
            rc.getString(RemoteConfigKeys.appBannerTone).trim();

        final isForceUpdate =
            _buildNumber != null && minBuild > _buildNumber!;

        if (maintenanceMode) {
          return _MaintenanceScreen(
            message: maintenanceMessage.isEmpty
                ? 'We are tuning Chlora right now. Please check back shortly.'
                : maintenanceMessage,
            onRetry: rc.refresh,
          );
        }

        if (isForceUpdate) {
          return _ForceUpdateScreen(
            updateUrl: updateUrl,
            onRetry: rc.refresh,
          );
        }

        final showBanner = appBannerEnabled && appBannerMessage.isNotEmpty;
        if (!showBanner) {
          return widget.child;
        }

        return Stack(
          children: [
            widget.child,
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: _RemoteBanner(
                  message: appBannerMessage,
                  tone: appBannerTone,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoteBanner extends StatelessWidget {
  const _RemoteBanner({required this.message, required this.tone});

  final String message;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final colors = _bannerColors(tone);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(18),
        color: colors.background,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(colors.icon, size: 18, color: colors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerColors _bannerColors(String tone) {
    switch (tone.toLowerCase()) {
      case 'warning':
        return const _BannerColors(
          background: Color(0xFFFFF7E6),
          border: Color(0xFFF2D28C),
          foreground: Color(0xFF6C4D00),
          icon: Icons.info_outline,
        );
      case 'success':
        return const _BannerColors(
          background: Color(0xFFE8F7EE),
          border: Color(0xFFBFE8CD),
          foreground: Color(0xFF135B2C),
          icon: Icons.check_circle_outline,
        );
      default:
        return const _BannerColors(
          background: Color(0xFFEAF1FF),
          border: Color(0xFFCADBFF),
          foreground: Color(0xFF23429B),
          icon: Icons.campaign_outlined,
        );
    }
  }
}

class _BannerColors {
  const _BannerColors({
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

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings_suggest_outlined,
                  size: 60, color: Color(0xFF2C6B3F)),
              const SizedBox(height: 18),
              const Text(
                'We will be right back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16301E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF526354),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.updateUrl, required this.onRetry});

  final String updateUrl;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_alt_outlined,
                  size: 60, color: Color(0xFF1C6DD0)),
              const SizedBox(height: 18),
              const Text(
                'Update required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E2A47),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please update to continue using Chlora.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF4E5D6A),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => _openStore(updateUrl),
                child: const Text('Update now'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onRetry(),
                child: const Text('Check again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(String url) async {
    final target = Uri.tryParse(url);
    if (target == null) {
      return;
    }
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }
}
