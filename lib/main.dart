import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/posthog_service.dart';
import 'services/remote_config_service.dart';
import 'services/onboarding_service.dart';
import 'components/app_remote_config_shell.dart';
import 'components/animated_logo_widget.dart';
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
  final initialization = _initializeApp();
  runApp(MyApp(initialization: initialization));
}

Future<void> _initializeApp() async {
  await dotenv.load(fileName: '.env');
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await RemoteConfigService.instance.init();
  await PosthogService.instance.init();
  await AuthService().ensureSignedIn();
  unawaited(BillingService.instance.init());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialization});

  final Future<void> initialization;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Firebase.apps.isNotEmpty) {
      RemoteConfigService.instance.refresh();
    }
  }

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
      home: StartupGate(initialization: widget.initialization),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.initialization});

  final Future<void> initialization;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  int _initialStep = 0;
  bool _initialized = false;
  bool _showSplash = true;
  Object? _startupError;
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialization;
    _prepareStartup();
  }

  Future<void> _prepareStartup() async {
    const minimumSplashDuration = Duration(seconds: 5);

    try {
      final results = await Future.wait<Object>([
        _initialization.then((_) => true),
        OnboardingService.instance.isOnboardingCompleted(),
        Future<void>.delayed(minimumSplashDuration).then((_) => true),
      ]);

      if (!mounted) return;

      final isCompleted = results[1] as bool;
      setState(() {
        _initialStep = isCompleted ? 2 : 0;
        _initialized = true;
        _showSplash = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _initialized = true;
        _showSplash = false;
      });
    }
  }

  Future<void> _retryStartup() async {
    if (!mounted) return;
    setState(() {
      _startupError = null;
      _initialized = false;
      _showSplash = true;
      _initialization = _initializeApp();
    });
    await _prepareStartup();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return AnimatedLogoSplashScreen(
        displayDuration: const Duration(seconds: 5),
        backgroundColor: Colors.white,
        accentColor: const Color(0xFF228B22),
      );
    }

    if (!_initialized) {
      return const AnimatedLogoSplashScreen(
        displayDuration: Duration(seconds: 5),
        backgroundColor: Colors.white,
        accentColor: Color(0xFF228B22),
      );
    }

    if (_startupError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedLogoWidget(size: 110, repeat: true),
                  const SizedBox(height: 24),
                  Text(
                    'LeafSnap AI could not finish loading.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF17382C),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Check your connection and try again.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E746D),
                          letterSpacing: 0,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF228B22),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _retryStartup,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppRemoteConfigShell(
      child: OnboardingFlow(initialStep: _initialStep),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late int _step;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
  }

  void _continueFromIntro() {
    setState(() => _step = 1);
    PosthogService.instance.trackScreen('Onboarding Step 2');
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.instance.completeOnboarding();
    if (!mounted) return;
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
        return AppBottomNav(); // 5-tab Bottom Nav renders all screens
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCurrentStep();
  }
}
