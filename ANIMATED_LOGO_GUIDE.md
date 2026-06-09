# Animated Logo Implementation Guide

Your app now has a beautiful animated leaf logo! Here's how to use it.

## Files Created

- `assets/animations/animated_logo.json` - Animated logo with glow and bounce effect
- `lib/components/animated_logo_widget.dart` - Reusable animated logo components
- Updated logo files:
  - `assets/icons/logo.png` - App logo
  - `assets/icons/logo_playstore_512.png` - Play Store submission logo

## Usage Examples

### 1. Simple Animated Logo (Recommended for Home/Dashboard)

```dart
import 'package:leafsnap_ai/components/animated_logo_widget.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedLogoWidget(
          size: 150,
          animate: true,
          repeat: true,
        ),
      ),
    );
  }
}
```

### 2. Splash Screen with Animated Logo

Use this for your app startup:

```dart
import 'package:leafsnap_ai/components/animated_logo_widget.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedLogoSplashScreen(
      title: 'Leaf Snap AI',
      subtitle: 'Identify plants instantly',
      displayDuration: Duration(seconds: 3),
      backgroundColor: Colors.white,
      accentColor: Colors.teal,
      onComplete: () {
        Navigator.of(context).pushReplacementNamed('/home');
      },
    );
  }
}
```

### 3. Static Logo (No Animation)

```dart
AnimatedLogoWidget(
  size: 100,
  animate: false,  // Shows static logo
)
```

### 4. Badge with Logo (Great for Navigation)

```dart
AnimatedLogoBadge(
  size: 80,
  animate: true,
  label: 'Plant ID',
  backgroundColor: Colors.teal.shade50,
)
```

### 5. Custom Animation Speed

```dart
AnimatedLogoWidget(
  size: 150,
  animate: true,
  repeat: true,
  animationSpeed: 1.5,  // 50% faster
)
```

## Integration in Your App

### Update Your Onboarding Screen

In `lib/screens/onboarding/screen1.dart`, replace or add alongside the current animation:

```dart
import 'package:leafsnap_ai/components/animated_logo_widget.dart';

class OnboardingScreen1 extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedLogoWidget(
          size: 200,
          animate: true,
          repeat: true,
        ),
        // ... rest of your UI
      ],
    );
  }
}
```

### Update Main App Navigation

In `lib/main.dart`, you could show the splash screen:

```dart
// After Firebase initialization in main()
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  // ... Firebase initialization ...
  
  runApp(
    MaterialApp(
      home: AnimatedLogoSplashScreen(
        displayDuration: Duration(seconds: 2),
        onComplete: () {
          // Navigate to home after splash
        },
      ),
      // ... rest of config
    ),
  );
}
```

### Update Bottom Navigation

In `lib/components/bottom_nav.dart`, you could add an animated logo:

```dart
import 'package:leafsnap_ai/components/animated_logo_widget.dart';

// In your nav bar or drawer
AnimatedLogoBadge(
  size: 60,
  animate: true,
  label: 'Leaf Snap AI',
)
```

## Play Store Submission

Your updated logo is ready for Play Store:

1. The file `assets/icons/logo_playstore_512.png` is your 512x512 icon
2. To use it as app icon in Google Play Console:
   - Go to **Google Play Console** → Your app
   - Navigate to **Release** → **Production**
   - Edit your store listing
   - Upload the **logo_playstore_512.png** as your icon
   - Ensure it meets Google Play requirements (transparent background, no text, etc.)

## Animation Details

The animated logo features:
- **Gentle bounce animation** - Logo moves up and down smoothly
- **Scaling effect** - Logo scales subtly for emphasis
- **Glow effect** - Decorative glow circles around the logo
- **Loop duration** - 2 seconds per loop (smooth and professional)

## Customizing the Animation

To modify the animation, edit `assets/animations/animated_logo.json`:

### Slow down animation:
Change `"op": 120` to `"op": 180` (higher = longer duration)

### Change loop duration:
In `animated_logo_widget.dart`, change:
```dart
duration: const Duration(milliseconds: 2000),  // Change from 2000 to desired ms
```

### Add more glow intensity:
Edit the opacity values in the JSON file (look for `"k": [0.2, 0.8, 0.6, 1]`)

## Tips for Best Results

1. **Performance**: The Lottie animation is pre-cached in your onboarding screens to avoid jank
2. **Responsive**: Use `MediaQuery` to adjust size based on device:
   ```dart
   AnimatedLogoWidget(
     size: MediaQuery.of(context).size.width * 0.4,
   )
   ```
3. **Theme Integration**: Match colors with your app theme
4. **Fallback**: If animation fails to load, the widget automatically shows the static logo

## Testing the Animation

Run your app and navigate to any screen using `AnimatedLogoWidget`:

```bash
flutter run
```

## Resources

- **Lottie Documentation**: https://lottie.dev/
- **Flutter Animation Guide**: https://flutter.dev/docs/development/ui/animations
- **Google Play Icon Requirements**: https://support.google.com/googleplay/android-developer/answer/1078870

## Troubleshooting

**Animation not showing?**
- Ensure `assets/animations/animated_logo.json` exists
- Check that lottie package is added to pubspec.yaml (already done ✓)
- Run `flutter pub get`

**Logo looks blurry?**
- Increase the `size` parameter
- Ensure your logo PNG is high quality (512x512 or higher)

**Animation stuttering?**
- The widget pre-caches animations, but you can disable:
  ```dart
  AnimatedLogoWidget(
    size: 150,
    animate: false,  // Use static instead
  )
  ```

