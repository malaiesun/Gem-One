import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/theme_prefs.dart';
import '../core/gemma_service.dart';
import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';

class GemOneApp extends StatefulWidget {
  const GemOneApp({super.key});

  @override
  State<GemOneApp> createState() => _GemOneAppState();
}

class _GemOneAppState extends State<GemOneApp> {
  @override
  void initState() {
    super.initState();
    ThemePrefs.instance.addListener(_onTheme);
    // load() is async; it calls notifyListeners() only if a saved accent exists,
    // triggering a rebuild that switches the theme before the first frame is visible.
    ThemePrefs.instance.load();
  }

  @override
  void dispose() {
    ThemePrefs.instance.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return GemmaServiceProvider(
      child: MaterialApp(
        title: 'Gem One',
        debugShowCheckedModeBanner: false,
        theme: GemOneTheme.dark(ThemePrefs.instance.accent),
        home: const _StartRouter(),
      ),
    );
  }
}

class _StartRouter extends StatelessWidget {
  const _StartRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboarding(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF070714),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 2,
              ),
            ),
          );
        }
        return snap.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }

  static Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }
}
