import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'progress/challenge_store.dart';
import 'progress/task_notifications.dart';
import 'screens/challenge_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding2.dart';
import 'screens/onboarding_steps_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Temporary: swipe any challenge day while testing. Set false to restore
  // calendar locking before release.
  ActiveChallenge.unlockSwipeForTesting = true;
  await TaskNotificationService.instance.init();
  await ChallengeStore.instance.load();
  runApp(const StickyPathApp());
}

class StickyPathApp extends StatelessWidget {
  const StickyPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StickyPath',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ink,
        fontFamily: AppFonts.sans,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.pink,
          brightness: Brightness.dark,
          primary: AppColors.pink,
        ),
      ),
      routes: _routes,
    );
  }
}

final Map<String, WidgetBuilder> _routes = {
  '/': (context) => ChallengeStore.instance.active != null
      ? const MainShell()
      : WelcomeScreen(
          onStart: () => Navigator.pushNamed(context, '/onboarding/steps'),
        ),
  '/onboarding/steps': (context) => OnboardingStepsScreen(
        onNext: () => Navigator.push(
          context,
          CupertinoPageRoute(
            settings: const RouteSettings(name: '/onboarding/2'),
            builder: (context) => Onboarding2(
              onNext: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  settings: const RouteSettings(name: '/challenge'),
                  builder: (context) => const ChallengeScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
  '/progress': (context) => const ProgressScreen(),
};
