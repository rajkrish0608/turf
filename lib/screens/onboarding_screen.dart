import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/territory_service.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.terrain,
      title: 'Claim your territory',
      subtitle: 'Walk, run, or ride to draw boundaries on the real-world map.',
    ),
    _OnboardingPage(
      icon: Icons.bolt_outlined,
      title: 'Compete for dominance',
      subtitle: 'Overlap rivals to steal their land. Defend yours by moving.',
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_outlined,
      title: 'Rise through the ranks',
      subtitle: 'Earn XP, level up, and climb the leaderboard.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  void _complete() {
    DemoTerritoryService().markOnboardingSeen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _RedirectToApp()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip (only on pages 0-1)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: isLast
                    ? const SizedBox(height: 36)
                    : TextButton(
                        onPressed: _complete,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ),

            // Pages — content positioned in upper third
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Icon(
                          page.icon,
                          size: 40,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: isActive ? 16 : 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

/// Simple redirect back to app router
class _RedirectToApp extends StatelessWidget {
  const _RedirectToApp();

  @override
  Widget build(BuildContext context) {
    // Rebuild app to pick up the new onboarding state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) {
          // Re-import and use TurfApp's router
          return const _LoginRedirect();
        }),
        (_) => false,
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _LoginRedirect extends StatelessWidget {
  const _LoginRedirect();

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
