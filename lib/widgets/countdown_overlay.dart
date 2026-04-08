import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CountdownOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const CountdownOverlay({super.key, required this.onComplete});

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _startCountdown();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _count = i);
      _animController.forward(from: 0);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _count = 0);
    _animController.forward(from: 0);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background.withAlpha(230),
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _count > 0 ? '$_count' : 'Go',
                      style: TextStyle(
                        fontSize: _count > 0 ? 72 : 48,
                        fontWeight: FontWeight.w700,
                        color: _count > 0
                            ? AppTheme.textPrimary
                            : AppTheme.primary,
                      ),
                    ),
                    if (_count > 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Get ready',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
