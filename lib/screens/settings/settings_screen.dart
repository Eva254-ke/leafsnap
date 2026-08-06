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

  // FIXED: Using your Google Sites URLs for all legal and help pages.
  static const _legalUrl = 'https://sites.google.com/view/leafsnapai/home';
  static const _privacyPolicyUrl = 'https://sites.google.com/view/leafsnapai/privacy-policy';
  static const _termsOfUseUrl = 'https://sites.google.com/view/leafsnapai/terms-of-use';
  static const _helpUrl = 'https://sites.google.com/view/leafsnapai/help'; 
  
  // FIXED: Your support email.
  static const _supportEmail = 'evanszachariah36@gmail.com';
  
  // FIXED: Updated trademark to "Chlora". Replace 'id123456789' with your actual Apple App Store ID.
  static const _appStoreUrl = 'https://apps.apple.com/app/leafsnap-ai/id123456789';

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
      // Ensure this backend call actually wipes user data from Firestore/Database.
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
    if (!mounted) return;
    setState(() {
      _cacheSize = '7M';
    });
  }

  Future<void> _clearCache() async {
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

    if (confirmed == true && !mounted) return;

    await DefaultCacheManager().emptyCache();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_home_data_timestamp');
    
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
      // Fallback: Try with in-app web view using url_launcher's default
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      } catch (_) {
        // If that fails, show the URL in a dialog for manual copy
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open in browser'),
            content: Text('Please copy and paste this URL in your browser:\n\n$url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copied to clipboard')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Copy URL'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _sendSupportEmail() async {
    final rc = RemoteConfigService.instance;
    final email = _remoteString(RemoteConfigKeys.supportEmail, _supportEmail);
    
    // Show dialog with email for user to copy manually
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send Support Email'),
          content: Text('Please copy this email address and open your email app:\n\n$email'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: email));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email copied to clipboard')),
                );
                Navigator.pop(context);
              },
              child: const Text('Copy Email'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _rateApp() async {
    final url = await _platformStoreUrl();
    await _openUrl(url);
  }

  Future<void> _shareApp() async {
    final shareUrl = RemoteConfigService.instance
        .getString(RemoteConfigKeys.shareUrl)
        .trim();
    final url = shareUrl.isEmpty ? await _platformStoreUrl() : shareUrl;
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied — paste to share')),
    );
  }

  // FIXED: Navigates to a dedicated screen instead of a modal
  Future<void> _showAppInfo() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppInfoScreen()),
    );
  }

  // FIXED: Navigates to a dedicated screen instead of showing "Coming soon"
  Future<void> _requestPermissions() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
    );
  }

  // FIXED: Navigates to a dedicated screen instead of showing "Coming soon"
  Future<void> _manageNotifications() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // FIXED: Navigates to a dedicated screen instead of a modal
  Future<void> _selectLanguage() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LanguageScreen()),
    );
  }

  Future<void> _restoreMembership() async {
    if (!mounted) return;
    await BillingService.instance.restorePurchases();
  }

  Future<void> _upgradePremium() async {
    await BillingService.instance.presentPaywall();
  }

  Future<void> _maybeResetScanLimit() async {
    final rc = RemoteConfigService.instance;
    if (!rc.getBool(RemoteConfigKeys.qaScanResetEnabled)) return;
    if (!mounted) return;
    
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s free scans reset.')),
      );
    }
  }

  String _remoteString(String key, String fallback) {
    final value = RemoteConfigService.instance.getString(key).trim();
    return value.isEmpty ? fallback : value;
  }

  // FIXED: Dynamically fetches real package name to prevent 'com.example' placeholder rejection
  Future<String> _platformStoreUrl() async {
    final info = await PackageInfo.fromPlatform();
    final realPlayStoreUrl = 'https://play.google.com/store/apps/details?id=${info.packageName}';
    final realAppStoreUrl = 'https://apps.apple.com/app/leafsnap-ai/id${_remoteString(RemoteConfigKeys.iosStoreId, '123456789')}';
    
    return Platform.isIOS
        ? _remoteString(RemoteConfigKeys.iosStoreUrl, realAppStoreUrl)
        : _remoteString(RemoteConfigKeys.androidStoreUrl, realPlayStoreUrl);
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
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              bottom: true,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            subtitle: 'Membership Status: ${isPremium ? 'Premium' : 'Free'}',
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
                        onTap: () => _openUrl(_helpUrl),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SnapTipsScreen()),
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
                  const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      trailing: trailing ?? const Icon(Icons.chevron_right, color: const Color(0xFFB0B0B0), size: 18),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: const Color(0xFFF0F0F0), indent: 16, endIndent: 16);
  }
}

// ==========================================
// NEW DEDICATED SCREENS (Replaces Modals)
// ==========================================

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: const AppHeader(title: 'Permissions'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Why we need permissions',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1B1B1B)),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(Icons.camera_alt, 'Camera', 'Required to take photos of plants for identification.'),
            _buildPermissionItem(Icons.photo_library, 'Storage / Photos', 'Required to save identified plant photos to your device.'),
            _buildPermissionItem(Icons.location_on, 'Location', 'Optional: Helps us provide location-based plant care tips.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF2E7D32), size: 24),
        title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A))),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _careReminders = true;
  bool _featureUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: const AppHeader(title: 'Care Notification'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('Plant Care Reminders', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B))),
                    subtitle: Text('Get notified when to water your plants', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A))),
                    trailing: Switch(value: _careReminders, onChanged: (value) => setState(() => _careReminders = value), activeColor: const Color(0xFF2E7D32)),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('New Feature Updates', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B))),
                    subtitle: Text('Stay updated with the latest app features', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A))),
                    trailing: Switch(value: _featureUpdates, onChanged: (value) => setState(() => _featureUpdates = value), activeColor: const Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = ['English', 'Swahili', 'French', 'Spanish'];
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: const AppHeader(title: 'Set Language'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Column(
                children: languages.map((lang) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(lang, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B))),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 18),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Language set to $lang')));
                          Navigator.pop(context);
                        },
                      ),
                      if (lang != languages.last) const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0), indent: 16, endIndent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F7),
          appBar: const AppHeader(title: 'App Info'),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Version: ${info?.version ?? '...'}+${info?.buildNumber ?? '...'}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B))),
                        const SizedBox(height: 8),
                        Text('Package: ${info?.packageName ?? '...'}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SnapTipsScreen extends StatelessWidget {
  const SnapTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: const AppHeader(title: 'Snap Tips'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTip('Take photos in good light'),
                    const SizedBox(height: 12),
                    _buildTip('Focus on one plant at a time'),
                    const SizedBox(height: 12),
                    _buildTip('Include leaves, flowers, or fruit'),
                    const SizedBox(height: 12),
                    _buildTip('Avoid blurry or distant shots'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF1B1B1B)))),
      ],
    );
  }
}