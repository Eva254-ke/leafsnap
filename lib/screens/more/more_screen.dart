import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../settings/settings_screen.dart';
import '../../components/app_header.dart';
import '../onboarding/camera/camera_screen.dart';
import '../onboarding/camera/camera_tools.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickTools = quickToolDefinitions;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF6),
      appBar: AppHeader(
        title: 'More',
        rightActions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Settings'),
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // Opacity fade on page load only (0 → 1, 300ms)
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _sectionHeader('Quick Tools'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickCard(quickTools[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(quickTools[1]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickCard(quickTools[2]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(quickTools[3]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionHeader('Smart IDs'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: smartIdToolDefinitions.length,
              itemBuilder: (context, index) {
                final tool = smartIdToolDefinitions[index];
                return _buildIdCard(tool);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1B1B1B)),
        ),
        const Spacer(),
        ...(trailing == null ? const <Widget>[] : <Widget>[trailing]),
      ],
    );
  }


  void _openTool(CameraToolDefinition tool) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'Camera'),
        builder: (_) => CameraScreen(initialToolId: tool.id),
      ),
    );
  }

  Widget _buildQuickCard(CameraToolDefinition tool) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTool(tool),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tool.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.accentColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                tool.title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1B1B1B)),
              ),
              const SizedBox(height: 4),
              Text(
                tool.subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              _supportBadge(tool),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdCard(CameraToolDefinition tool) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTool(tool),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tool.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Icon(tool.icon, color: tool.accentColor, size: 36),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1B1B1B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  _supportBadge(tool),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportBadge(CameraToolDefinition tool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tool.supportTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tool.supportBadgeLabel,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tool.supportColor,
        ),
      ),
    );
  }
}
