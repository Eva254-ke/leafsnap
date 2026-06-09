import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _kOnboardingCompleted = 'onboarding_completed';

  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  /// Check if user has completed onboarding
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingCompleted) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleted, true);
  }

  /// Reset onboarding (for debugging/logout)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingCompleted);
  }
}
