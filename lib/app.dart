import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'services/territory_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class TurfApp extends StatelessWidget {
  const TurfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  final _service = DemoTerritoryService();

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      // Supabase not initialized — will rely on manual state
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    if (!_service.isLoggedIn) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
