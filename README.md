# LeafSnap AI

A Flutter-based mobile application for intelligent plant identification, diagnosis, and personalized care recommendations — with offline-first capabilities.

## Features

**Plant Identification**: Identify plants using your device camera or gallery photos
**Disease Diagnosis**: Get AI-powered diagnostics for plant health issues
**Personalized Care Tips**: Receive tailored plant care recommendations based on location and conditions
**Location-Based Services**: Geo-aware recommendations and local plant databases
**Offline-First Architecture**: Core functionality works without internet connectivity
**Secure Authentication**: Firebase authentication with Google Sign-in support
**Cloud Sync**: Seamless data synchronization with Firestore when connected
**Cross-Platform**: Native support for iOS, Android, Web, macOS, Windows, and Linux

## Tech Stack

### Frontend
- **Flutter** 3.10.7+ - UI framework for cross-platform development
- **Lottie** - Smooth animations and interactive UI components
- **Google Fonts** - Beautiful typography

### Backend & Services
- **Firebase Core** - Backend infrastructure
- **Firebase Authentication** - User authentication and management
- **Cloud Firestore** - Real-time NoSQL database
- **Firebase Storage** - Cloud file storage for plant images and data

### Device Capabilities
- **Camera** - Plant photo capture
- **Image Picker** - Gallery image selection
- **Geolocator** - GPS location services
- **Geocoding** - Location-to-address conversion

### Local Storage & Caching
- **Shared Preferences** - Local key-value storage
- **Flutter Cache Manager** - Intelligent image and data caching
- **Cached Network Image** - Efficient image loading and caching

### Analytics & Performance
- **PostHog** - Event tracking and feature analytics
- **Package Info Plus** - App version and build information

### Utilities
- **URL Launcher** - Deep linking and URL handling
- **Permission Handler** - Runtime permission requests
- **Share Plus** - Native sharing capabilities

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── components/               # Reusable UI components
├── diagnose/                # Plant diagnosis features
├── models/                  # Data models
├── plant/                   # Plant-related features
├── screens/                 # App screens/pages
│   ├── onboarding/         # Initial onboarding flow
│   └── [other screens]
└── services/               # Business logic & API services
    ├── auth_service.dart
    └── posthog_service.dart

android/                      # Android-specific code
ios/                         # iOS-specific code
web/                         # Web platform code
windows/                     # Windows platform code
linux/                       # Linux platform code
macos/                       # macOS platform code
```

## Getting Started

### Prerequisites
- Flutter SDK 3.10.7 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Firebase project setup

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/leafsnap_ai.git
   cd leafsnap_ai
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Download `google-services.json` for Android and `GoogleService-Info.plist` for iOS
   - Place them in the respective platform directories
   - Update `firebase_options.dart` with your Firebase credentials

4. **Configure environment variables**
   - Create a `.env` file in the project root
   - Add your configuration variables (API keys, endpoints, etc.)

5. **Run the app**
   ```bash
   flutter run
   ```

## Build & Release

### Android Release
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS Release
```bash
flutter build ios --release
```

### Web Release
```bash
flutter build web --release
```

## Available Scripts

```bash
# Analyze code for issues
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Build for all platforms
flutter build --help
```

## Firebase Setup

### Authentication
- Google Sign-in integration
- Email/password authentication
- Secure token management

### Firestore Database
- User profiles and preferences
- Plant care history
- Diagnosis records
- Community recommendations

### Storage
- User-uploaded plant images
- Processed diagnosis results
- Cache for offline access

## Contributing

We welcome contributions! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development Workflow

### Code Style
- Follow Dart style guide
- Use `dart format` for formatting
- Use `flutter analyze` to check code quality

### Git Workflow
- Use descriptive commit messages
- Keep commits focused and atomic
- Reference issues in commit messages

## Troubleshooting

### Build Issues
- Run `flutter clean` to clear build artifacts
- Run `flutter pub get` to update dependencies
- Check platform-specific issues (Android SDK, Xcode version, etc.)

### Firebase Connection
- Verify Firebase project configuration
- Check API keys and permissions
- Ensure network connectivity

### Camera/Permissions
- Grant necessary permissions when prompted
- Check device settings for app permissions

## Performance Tips

- **Offline-First**: The app prioritizes offline functionality
- **Image Caching**: Images are automatically cached locally
- **Database Sync**: Firestore syncs intelligently when connected
- **Animation Optimization**: Lottie animations are GPU-accelerated

## Security Considerations

- All Firebase communication is encrypted
- API keys are stored securely
- User data is encrypted in transit and at rest
- Implement proper authentication checks

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support & Contact

For issues, feature requests, or questions:
- Open an issue on GitHub
- Contact: support@leafsnapai.com

## Roadmap

- [ ] ML-based plant identification improvements
- [ ] Community plant database expansion
- [ ] AR visualization features
- [ ] Advanced disease detection
- [ ] Smart watering reminders
- [ ] Multi-language support

---

**LeafSnap AI** - Bringing AI-powered plant care to everyone
