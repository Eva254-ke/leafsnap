import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/posthog_service.dart';
import 'screens/onboarding/screen1.dart';
import 'screens/onboarding/screen2.dart';
// ignore: unused_import
import 'screens/onboarding/shared.dart';
import 'components/bottom_nav.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver = PosthogRouteObserver();

class PosthogRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _trackRoute(Route<dynamic>? route) {
    if (route is PageRoute<dynamic>) {
      final screenName = route.settings.name ?? route.runtimeType.toString();
      PosthogService.instance.trackScreen(screenName);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackRoute(previousRoute);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PosthogService.instance.init();
  await AuthService().ensureSignedIn();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LeafSnap AI',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Inter',
      ),
      navigatorObservers: [routeObserver],
      home: const OnboardingFlow(),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  void _continueFromIntro() {
    setState(() => _step = 1);
    PosthogService.instance.trackScreen('Onboarding Step 2');
  }

  void _completeOnboarding() {
    setState(() => _step = 2);
    PosthogService.instance.trackScreen('Home');
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return OnboardingScreen1(onContinue: _continueFromIntro);
      case 1:
        return OnboardingScreen2(onComplete: _completeOnboarding);
      default:
        return AppBottomNav();  // 5-tab Bottom Nav renders all screens
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCurrentStep();
  }
}