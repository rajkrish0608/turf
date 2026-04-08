import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/game_stats.dart';

class CelebrationDialog extends StatefulWidget {
  final double areaSqm;
  final int xpEarned;
  final bool wasSteal;
  final String activityType;
  final double distanceMeters;
  final int durationSeconds;
  final GameStats gameStats;
  final VoidCallback onDismiss;

  const CelebrationDialog({
    super.key,
    required this.areaSqm,
    required this.xpEarned,
    required this.wasSteal,
    required this.activityType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.gameStats,
    required this.onDismiss,
  });

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _counterController;
  late final Animation<double> _counterAnim;
  late final AnimationController _xpPulseController;
  late final Animation<double> _xpPulseAnim;

  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    // Slide up from bottom
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Area counter tick-up
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _counterAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOut),
    );

    // XP pulse
    _xpPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _xpPulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(_xpPulseController);

    _runEntrySequence();
  }

  Future<void> _runEntrySequence() async {
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _counterController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _xpPulseController.forward();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _showButton = true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _counterController.dispose();
    _xpPulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatArea(double area) {
    if (area >= 1000) {
      return '${(area / 1000).toStringAsFixed(1)}K';
    }
    return area.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background.withAlpha(242),
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.wasSteal ? Icons.bolt : Icons.flag_outlined,
                  size: 40,
                  color: widget.wasSteal ? AppTheme.danger : AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.wasSteal ? 'Territory stolen' : 'Territory captured',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color:
                        widget.wasSteal ? AppTheme.danger : AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.surfaceContainer(),
                  child: Column(
                    children: [
                      // Area with counter animation
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Area',
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 14)),
                            AnimatedBuilder(
                              animation: _counterController,
                              builder: (context, _) {
                                final value =
                                    widget.areaSqm * _counterAnim.value;
                                return Text(
                                  '${_formatArea(value)} m²',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                          height: 1, color: AppTheme.borderColor),
                      // XP with pulse
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('XP earned',
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 14)),
                            ScaleTransition(
                              scale: _xpPulseAnim,
                              child: Text(
                                '+${widget.xpEarned}',
                                style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                          height: 1, color: AppTheme.borderColor),
                      _row('Distance',
                          '${widget.distanceMeters.toStringAsFixed(0)} m'),
                      const Divider(
                          height: 1, color: AppTheme.borderColor),
                      _row('Duration',
                          _formatDuration(widget.durationSeconds)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Level
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.surfaceContainer(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lv.${widget.gameStats.level} ${widget.gameStats.title}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${widget.gameStats.xpToNextLevel} XP to next',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: widget.gameStats.levelProgress,
                          backgroundColor: AppTheme.surfaceElevated,
                          valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primary),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (widget.gameStats.currentStreak > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: AppTheme.surfaceContainer(
                        border: AppTheme.warningSubtle),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.gameStats.currentStreak}-day streak · ${widget.gameStats.streakMultiplier.toStringAsFixed(1)}× XP',
                          style: const TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Continue button — fades in after animations
                AnimatedOpacity(
                  opacity: _showButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _showButton ? widget.onDismiss : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
