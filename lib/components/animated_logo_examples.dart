import 'package:flutter/material.dart';
import 'package:leafsnap_ai/components/animated_logo_widget.dart';

/// Example implementation showing how to use the animated logo
/// Copy and adapt these examples to your screens

class AnimatedLogoExamples extends StatelessWidget {
  const AnimatedLogoExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animated Logo Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Example 1: Simple Animated Logo
          _buildExample(
            title: 'Simple Animated Logo',
            description: 'Basic logo with animation loop',
            child: AnimatedLogoWidget(
              size: 150,
              animate: true,
              repeat: true,
            ),
          ),

          // Example 2: Static Logo
          _buildExample(
            title: 'Static Logo',
            description: 'No animation - use as app icon',
            child: AnimatedLogoWidget(
              size: 120,
              animate: false,
            ),
          ),

          // Example 3: Animated Badge
          _buildExample(
            title: 'Animated Badge',
            description: 'Logo in a styled badge',
            child: AnimatedLogoBadge(
              size: 100,
              animate: true,
              label: 'Leaf Snap',
              backgroundColor: Colors.teal.shade50,
            ),
          ),

          // Example 4: Large Animated Logo
          _buildExample(
            title: 'Large Animated Logo',
            description: 'Perfect for splash screens',
            child: AnimatedLogoWidget(
              size: 200,
              animate: true,
              repeat: true,
            ),
          ),

          // Example 5: Multiple Animated Logos
          _buildExample(
            title: 'Multiple Logos',
            description: 'Logos in a row',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedLogoWidget(size: 80, animate: true),
                AnimatedLogoWidget(size: 100, animate: true),
                AnimatedLogoWidget(size: 80, animate: true),
              ],
            ),
          ),

          // Example 6: Animated Logo with Custom Speed
          _buildExample(
            title: 'Faster Animation',
            description: 'Logo with increased animation speed',
            child: AnimatedLogoWidget(
              size: 150,
              animate: true,
              repeat: true,
              animationSpeed: 1.5,
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const AnimatedLogoSplashScreenExample(),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen),
            label: const Text('View Full Splash Screen'),
          ),
        ],
      ),
    );
  }

  Widget _buildExample({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

class AnimatedLogoSplashScreenExample extends StatelessWidget {
  const AnimatedLogoSplashScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedLogoSplashScreen(
      title: 'Leaf Snap AI',
      subtitle: 'Identify plants instantly with AI',
      displayDuration: const Duration(seconds: 4),
      backgroundColor: Colors.white,
      accentColor: Colors.teal,
      onComplete: () {
        Navigator.of(context).pop();
      },
    );
  }
}

/// Integration patterns for your actual screens

/// Pattern 1: Use in Onboarding
class OnboardingWithAnimatedLogo extends StatelessWidget {
  const OnboardingWithAnimatedLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedLogoWidget(
              size: 200,
              animate: true,
              repeat: true,
            ),
            const SizedBox(height: 40),
            Text(
              'Welcome to Leaf Snap AI',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Identify any plant with your camera',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pattern 2: Use in Navigation/Drawer
class DrawerWithAnimatedLogo extends StatelessWidget {
  const DrawerWithAnimatedLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedLogoBadge(
                  size: 80,
                  animate: true,
                  label: 'Leaf Snap AI',
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Favorites'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Pattern 3: Use in Dashboard/Home
class DashboardWithAnimatedLogo extends StatelessWidget {
  const DashboardWithAnimatedLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            AnimatedLogoBadge(
              size: 120,
              animate: true,
              backgroundColor: Colors.teal.shade50,
            ),
            const SizedBox(height: 40),
            Text(
              'Tap the camera to identify a plant',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Scan Plant',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
