# Quick Start: Add Animated Logo to Your App

## Step 1: Import in Your Screen
```dart
import 'package:leafsnap_ai/components/animated_logo_widget.dart';
```

## Step 2: Add to Your Screen

### Option A: Replace/Add to Onboarding
In your `lib/screens/onboarding/screen1.dart` or `screen2.dart`:

```dart
class OnboardingScreen1 extends StatefulWidget {
  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // ⬇️ Add this animated logo
            AnimatedLogoWidget(
              size: 200,
              animate: true,
              repeat: true,
            ),
            const SizedBox(height: 40),
            // ... rest of your content
          ],
        ),
      ),
    );
  }
}
```

### Option B: Use as Splash Screen
Replace your initial loading screen in `main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MaterialApp(
      home: AnimatedLogoSplashScreen(
        title: 'Leaf Snap AI',
        subtitle: 'Identify plants with AI',
        displayDuration: Duration(seconds: 3),
        onComplete: () async {
          // After splash, navigate to app
          // or call your initial setup
        },
      ),
    ),
  );
}
```

### Option C: Add to Home Screen
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedLogoBadge(
              size: 150,
              animate: true,
              label: 'Leaf Snap AI',
            ),
            // ... rest of UI
          ],
        ),
      ),
    );
  }
}
```

## Step 3: Customize Size & Animation

```dart
// Smaller logo
AnimatedLogoWidget(size: 100, animate: true)

// Static (no animation)
AnimatedLogoWidget(size: 150, animate: false)

// Faster animation
AnimatedLogoWidget(size: 150, animate: true, animationSpeed: 1.5)

// No loop (one-shot animation)
AnimatedLogoWidget(
  size: 150, 
  animate: true,
  repeat: false,
  onAnimationComplete: () => print('Animation done!'),
)
```

## Step 4: For Play Store

The new logo is already set up:
- File: `assets/icons/logo_playstore_512.png`
- Upload to Google Play Console as your app icon

## Test It!

Run your app:
```bash
flutter run
```

View examples in:
```bash
flutter run lib/components/animated_logo_examples.dart
```

## Troubleshooting

**Logo not showing?**
- Run: `flutter pub get`
- Check: `assets/animations/animated_logo.json` exists
- Rebuild: `flutter clean && flutter pub get`

**Animation stuttering?**
- Use `animate: false` for static version
- Or reduce size for lower-end devices

**Want to customize animation?**
- Edit JSON: `assets/animations/animated_logo.json`
- Or modify duration in `animated_logo_widget.dart`

## How It's Animated (Mecor Style)

Your app now uses **Lottie** animations (like Mecor and many professional apps):
- Vector-based animations (small file size)
- Smooth 60fps on all devices
- Easily customizable
- No code changes needed to modify animation

The animation includes:
- ✨ Glow effect
- 📈 Scale effect  
- ⬆️ Bounce effect
- 🔄 Smooth looping

