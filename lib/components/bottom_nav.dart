import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/onboarding/diagnose/diagnose_screen.dart';
import '../screens/onboarding/camera/camera_screen.dart';
import '../screens/onboarding/home/home_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/my_plants/my_plants_screen.dart';
import '../services/posthog_service.dart';
import '../services/remote_config_service.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({Key? key}) : super(key: key);

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _selectedIndex = 0;

  Widget get _homeScreen => const HomeScreen();
  Widget get _diagnoseScreen => const DiagnoseScreen();
  Widget get _cameraScreen => const CameraScreen();
  Widget get _plantsScreen => const MyPlantsScreen();
  Widget get _moreScreen => const MoreScreen();

  List<Widget> get _screens => [
        _homeScreen,
        _diagnoseScreen,
        _cameraScreen,
        _plantsScreen,
        _moreScreen,
      ];

  void _onItemTapped(int index) {
    final rc = RemoteConfigService.instance;
    final diagnoseEnabled =
        rc.getBool(RemoteConfigKeys.featureDiagnoseEnabled);
    final cameraEnabled =
        rc.getBool(RemoteConfigKeys.featureCameraEnabled);

    if (index == 1 && !diagnoseEnabled) {
      _showFeatureDisabled('Diagnose is coming soon.');
      return;
    }
    if (index == 2 && !cameraEnabled) {
      _showFeatureDisabled('Camera is coming soon.');
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Camera'),
          builder: (context) => const CameraScreen(),
        ),
      );
      PosthogService.instance.trackScreen('Camera');
    } else {
      setState(() => _selectedIndex = index);
      final screenName = <int, String>{
        0: 'Home',
        1: 'Diagnose',
        3: 'My Plants',
        4: 'More',
      }[index];
      if (screenName != null) {
        PosthogService.instance.trackScreen(screenName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.instance;
    final diagnoseEnabled =
        rc.getBool(RemoteConfigKeys.featureDiagnoseEnabled);
    final cameraEnabled =
        rc.getBool(RemoteConfigKeys.featureCameraEnabled);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: Container(
        height: 82,
        width: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 8),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'main_camera_fab',
          onPressed: () => _onItemTapped(2),
          backgroundColor:
              cameraEnabled ? const Color(0xFF22A45D) : Colors.grey.shade400,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.camera_alt_rounded, size: 30, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 74,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _navItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
              ),
              _navItem(
                icon: Icons.add_box_outlined,
                label: 'Diagnose',
                index: 1,
                enabled: diagnoseEnabled,
              ),
              const SizedBox(width: 40),
              _navItem(
                icon: Icons.spa_outlined,
                label: 'My Plants',
                index: 3,
              ),
              _navItem(
                icon: Icons.grid_view_rounded,
                label: 'More',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    bool enabled = true,
  }) {
    final isSelected = _selectedIndex == index;
    final color = enabled
        ? (isSelected ? const Color(0xFF22A45D) : Colors.grey)
        : Colors.grey.shade400;

    return InkWell(
      onTap: enabled ? () => _onItemTapped(index) : null,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureDisabled(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
