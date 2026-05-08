import 'package:posthog_flutter/posthog_flutter.dart';

class PosthogService {
  PosthogService._();

  static final PosthogService instance = PosthogService._();

  Future<void> init() async {
    final config = PostHogConfig('phc_CjcZEL9LjsH5QzgKYJgFNjvBcWshdYC8jft7GoV7AdVh')
      ..host = 'https://us.i.posthog.com'
      ..captureApplicationLifecycleEvents = true
      ..debug = true;

    await Posthog().setup(config);
  }

  Future<void> capture(String eventName, {Map<String, Object>? properties}) async {
    await Posthog().capture(eventName: eventName, properties: properties);
  }

  Future<void> trackScreen(String screenName) async {
    await Posthog().screen(screenName: screenName);
  }
}
