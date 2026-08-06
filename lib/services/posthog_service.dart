import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

class PosthogService {
  PosthogService._();

  static final PosthogService instance = PosthogService._();

  Future<void> init() async {
    final apiKey = dotenv.env['POSTHOG_API_KEY'];
    final host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.posthog.com';
    
    if (apiKey == null || apiKey.isEmpty) {
      print('⚠️ PostHog API key not found in .env');
      return;
    }

    final config = PostHogConfig(apiKey)
      ..host = host
      ..captureApplicationLifecycleEvents = true
      ..sessionReplay = true
      ..debug = kDebugMode;

    config.sessionReplayConfig.maskAllTexts = false;
    config.sessionReplayConfig.maskAllImages = false;

    await Posthog().setup(config);
    print('✅ PostHog initialized with host: $host');
  }

  Future<void> capture(String eventName, {Map<String, Object>? properties}) async {
    await Posthog().capture(eventName: eventName, properties: properties);
  }

  Future<void> trackScreen(String screenName) async {
    await Posthog().screen(screenName: screenName);
  }
}
