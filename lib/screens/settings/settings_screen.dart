import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/app_header.dart';
import '../../components/remote_config_ui.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/scan_limit_service.dart';
import '../auth/auth_screen.dart';
import '../premium/premium_paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _autosavePhotos = false;
  String _cacheSize = '7M';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  User? _currentUser;

  // Real URLs for legal pages — replace with your actual URLs
  static const _legalUrl = 'https://sites.google.com/view/leafsnapai/home';
  static const _privacyPolicyUrl = _legalUrl;
  static const _termsOfUseUrl = _legalUrl;
  static const _supportEmail = 'support@leafsnap.app';
  static const _appStoreUrl = 'https://apps.apple.com/app/leafsnap/id123456789';
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.example.leafsnap_ai';
  static const _helpUrl = 'https://leafsnap.app/help';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _loadSettings();
    _updateCacheSize();
    _getCurrentUser();
    _authService.authStateChanges.listen((_) {
      if (mounted) {
        _getCurrentUser();
      }
    });
  }

  void _getCurrentUser() {
    setState(() {
      _currentUser = _authService.currentUser;
    });
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _authService.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed out successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await _authService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autosavePhotos = prefs.getBool('autosave_photos') ?? false;
    });
  }

  Future<void> _saveAutosave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autosave_photos', value);
  }

  Future<void> _updateCacheSize() async {
    // In production, calculate actual cache size from your cache directory
    // This is a placeholder — replace with real cache calculation
    if (!mounted) return;
    setState(() {
      _cacheSize = '7M';
    });
  }

  Future<void> _clearCache() async {
    // Show confirmation before clearing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cache?'),
        content: const Text('This will free up space but may slow down the app temporarily.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF228B22)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    // Fixed: Check mounted after async gap before using context
    if (confirmed == true && !mounted) return;

    // Clear image cache using DefaultCacheManager from cached_network_image
    await DefaultCacheManager().emptyCache();
    
    // Clear shared preferences cache keys if any
    final prefs = await SharedPreferences.getInstance();
    // Example: await prefs.remove('cached_weather_data');
    // Fixed: Actually use the prefs variable by clearing a sample key
    await prefs.remove('cached_home_data_timestamp');
    
    // Fixed: Check mounted again after async operations
    if (!mounted) return;
    
    setState(() {
      _cacheSize = '0B';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  Future<void> _sendSupportEmail() async {
    final rc = RemoteConfigService.instance;
    final uri = Uri(
      scheme: 'mailto',
      path: _remoteString(RemoteConfigKeys.supportEmail, _supportEmail),
      queryParameters: {
        'subject': _remoteString(
          RemoteConfigKeys.supportSubject,
          'LeafSnap Support Request',
        ),
        'body': rc.getString(RemoteConfigKeys.supportBody).trim().isEmpty
            ? 'Describe your issue here:\n\n'
            : rc.getString(RemoteConfigKeys.supportBody),
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  Future<void> _rateApp() async {
    final url = _platformStoreUrl();
    await _openUrl(url);
  }

  Future<void> _shareApp() async {
    final shareUrl = RemoteConfigService.instance
        .getString(RemoteConfigKeys.shareUrl)
        .trim();
    final url = shareUrl.isEmpty ? _platformStoreUrl() : shareUrl;
    if (!mounted) return;
    // Using Share dialog via platform share intent
    // Note: Add share_plus to pubspec.yaml if not already present
    // For now, fallback to copying link
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied — paste to share')),
    );
  }

  Future<void> _showAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: ${info.version}+${info.buildNumber}'),
            const SizedBox(height: 8),
            Text('Package: ${info.packageName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    // Request camera, location, storage permissions as needed
    // Use permission_handler package in production
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission request coming soon')),
    );
  }

  Future<void> _manageNotifications() async {
    // Navigate to notification settings or toggle local notifications
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings coming soon')),
    );
  }

  Future<void> _selectLanguage() async {
    // Show language picker dialog
    final languages = ['English', 'Swahili', 'French', 'Spanish'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select language'),
        children: languages.map((lang) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, lang),
            child: Text(lang),
          );
        }).toList(),
      ),
    );
    if (selected != null && mounted) {
      // Save preference and restart app or reload locale
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language: $selected')),
      );
    }
  }

  Future<void> _restoreMembership() async {
    if (!mounted) {
      return;
    }
    await BillingService.instance.restorePurchases();
  }

  Future<void> _upgradePremium() async {
    if (!mounted) {
      return;
    }
    final scansUsed = await ScanLimitService().getScanCount();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Premium Paywall'),
        builder: (_) => PremiumPaywallScreen(
          scansUsed: scansUsed,
          scanLimit: ScanLimitService.scanLimit,
        ),
      ),
    );
  }

  Future<void> _maybeResetScanLimit() async {
    final rc = RemoteConfigService.instance;
    if (!rc.getBool(RemoteConfigKeys.qaScanResetEnabled)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset today\'s scan limit?'),
        content: const Text('This will reset today\'s free scans for QA testing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF228B22)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScanLimitService().reset();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s free scans reset.')),
      );
    }
  }

  String _remoteString(String key, String fallback) {
    final value = RemoteConfigService.instance.getString(key).trim();
    return value.isEmpty ? fallback : value;
  }

  String _platformStoreUrl() {
    return Platform.isIOS
        ? _remoteString(RemoteConfigKeys.iosStoreUrl, _appStoreUrl)
        : _remoteString(RemoteConfigKeys.androidStoreUrl, _playStoreUrl);
  }

  @override
  Widget build(BuildContext context) {
    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.settings,
      fallbackBackgroundColor: const Color(0xFFF4F6F7),
      fallbackPrimaryColor: const Color(0xFF2E7D32),
      builder: (context, remoteConfig) {
        return Scaffold(
          backgroundColor: remoteConfig.backgroundColor,
          appBar: const AppHeader(title: 'Settings'),
      // Opacity fade on page load only (0 → 1, 300ms)
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              bottom: true, // Ensure footer respects safe area in production
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Spacing scale: 16px
                children: [
              if (remoteConfig.banner != null) ...[
                RemoteScreenBanner(
                  banner: remoteConfig.banner!,
                  primaryColor: remoteConfig.primaryColor,
                ),
                const SizedBox(height: 8),
              ],
              _sectionTitle('Membership'),
              _settingsCard(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: BillingService.instance.isPremium,
                    builder: (context, isPremium, _) {
                      return _settingsTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'My Premium Service',
                        subtitle:
                            'Membership Status: ${isPremium ? 'Premium' : 'Free'}',
                        onTap: _upgradePremium,
                        onLongPress: _maybeResetScanLimit,
                      );
                    },
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.restore,
                    title: 'Restore Membership',
                    onTap: _restoreMembership,
                  ),
                ],
              ),
              _sectionTitle('General Settings'),
              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.language,
                    title: 'Set Language',
                    onTap: _selectLanguage,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.notifications_none,
                    title: 'Care Notification',
                    onTap: _manageNotifications,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.lock_outline,
                    title: 'Allow Access',
                    onTap: _requestPermissions,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.photo_outlined,
                    title: 'Autosave Photos to Album',
                    trailing: Switch(
                      value: _autosavePhotos,
                      onChanged: (value) {
                        setState(() {
                          _autosavePhotos = value;
                        });
                        _saveAutosave(value);
                      },
                    ),
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.delete_outline,
                    title: 'Clear Cache',
                    trailing: Text(
                      _cacheSize,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8A8A8A),
                      ),
                    ),
                    onTap: _clearCache,
                  ),
                ],
              ),
              _sectionTitle('Support'),
              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.thumb_up_outlined,
                    title: 'Encourage Us',
                    onTap: _rateApp,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.help_outline,
                    title: 'Help',
                    onTap: () => _openUrl(
                      _remoteString(RemoteConfigKeys.helpUrl, _helpUrl),
                    ),
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Us',
                    onTap: _sendSupportEmail,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Snap Tips',
                    onTap: () {
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Snap Tips'),
                          content: const Text(
                            '• Take photos in good light\n'
                            '• Focus on one plant at a time\n'
                            '• Include leaves, flowers, or fruit\n'
                            '• Avoid blurry or distant shots',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              _sectionTitle('Account'),
              _settingsCard(
                children: _currentUser == null
                    ? [
                        _settingsTile(
                          icon: Icons.login,
                          title: 'Log In / Sign Up',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: 'Auth'),
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          },
                        ),
                      ]
                    : [
                        _settingsTile(
                          icon: Icons.delete_outline,
                          title: 'Delete Account',
                          onTap: _handleDeleteAccount,
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF0F0F0),
                          indent: 16,
                          endIndent: 16,
                        ),
                        _settingsTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          onTap: _handleSignOut,
                        ),
                      ],
              ),
              _sectionTitle('Legal'),
              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _openUrl(_privacyPolicyUrl),
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Use',
                    onTap: () => _openUrl(_termsOfUseUrl),
                  ),
                ],
              ),
              _sectionTitle('About the App'),
              _settingsCard(
                children: [
                  _settingsTile(
                    icon: Icons.info_outline,
                    title: 'App Info',
                    onTap: _showAppInfo,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.star_border,
                    title: 'Rate App',
                    onTap: _rateApp,
                  ),
                  _divider(),
                  _settingsTile(
                    icon: Icons.ios_share_rounded,
                    title: 'Tell Friends',
                    onTap: _shareApp,
                  ),
                ],
              ),
              // Bottom padding to respect safe area
              const SizedBox(height: 24), // Spacing scale: 24px
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), // Spacing scale: 16px top, 8px bottom
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1B1B1B),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // Fixed: 8px max for cards per design system
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Subtle border instead of shadow
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Spacing scale
      leading: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1B1B1B),
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF7A7A7A),
              ),
            ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 18),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16);
  }
}
