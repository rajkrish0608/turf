import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/territory_service.dart';
import '../../models/game_stats.dart';
import '../login_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _service = DemoTerritoryService();

  bool isEditing = false;
  bool isSaving = false;

  late TextEditingController _avatarController;
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _service.dataChanged.addListener(_refresh);
  }

  void _initControllers() {
    final player = _service.currentPlayer;
    _avatarController = TextEditingController(text: player.avatar);
    _usernameController = TextEditingController(text: player.username);
  }

  void _resetControllers() {
    final player = _service.currentPlayer;
    _avatarController.text = player.avatar;
    _usernameController.text = player.username;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.dataChanged.removeListener(_refresh);
    _avatarController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => isSaving = true);
    try {
      _service.updateProfile(
        username: _usernameController.text.trim(),
        avatar: _avatarController.text.trim().isEmpty
            ? '😎'
            : _avatarController.text.trim(),
      );
      setState(() => isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = _service.currentPlayer;
    final stats = _service.gameStats;
    final history = _service.getCaptureHistory();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                IconButton(
                  icon: Icon(
                    isEditing ? Icons.close : Icons.edit_outlined,
                    color: isEditing ? AppTheme.danger : AppTheme.textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      isEditing = !isEditing;
                      if (!isEditing) _resetControllers();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar + Name + Level
            Row(
              children: [
                isEditing
                    ? SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _avatarController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius),
                            ),
                            counterText: '',
                            contentPadding: const EdgeInsets.all(8),
                          ),
                          maxLength: 2,
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radius),
                          border:
                              Border.all(color: AppTheme.borderColor),
                        ),
                        child: Center(
                          child: Text(
                            player.avatar,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: isEditing
                      ? TextField(
                          controller: _usernameController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lv.${stats.level} ${stats.title}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // XP Progress
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.surfaceContainer(),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${stats.totalXP} XP',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${stats.xpToNextLevel} to next level',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: stats.levelProgress,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primary),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 14),
              decoration: AppTheme.surfaceContainer(),
              child: Row(
                children: [
                  _StatItem(
                      label: 'Captures',
                      value: '${stats.totalCaptures}'),
                  _divider(),
                  _StatItem(
                    label: 'Distance',
                    value:
                        '${(stats.totalDistanceMeters / 1000).toStringAsFixed(1)} km',
                  ),
                  _divider(),
                  _StatItem(
                    label: 'Streak',
                    value: '${stats.currentStreak}d',
                    highlight: stats.currentStreak > 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save button (edit mode)
            if (isEditing) ...[
              isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save changes'),
                    ),
              const SizedBox(height: 20),
            ],

            // Activity History
            const Text(
              'Recent activity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.surfaceContainer(),
                child: const Center(
                  child: Text(
                    'No captures yet. Start your first run.',
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ...history.take(10).map(
                    (record) => _HistoryItem(record: record),
                  ),

            const SizedBox(height: 24),

            // Sign out
            OutlinedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await _service.signOut();
                if (mounted) {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.dangerSubtle),
              ),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.borderColor,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppTheme.warning : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final CaptureRecord record;

  const _HistoryItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final activityIcons = {
      'Walk': Icons.directions_walk,
      'Run': Icons.directions_run,
      'Cycle': Icons.directions_bike,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            activityIcons[record.activityType] ?? Icons.directions_run,
            color: record.wasSteal ? AppTheme.danger : AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${record.areaSqm.toStringAsFixed(0)} m²',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (record.wasSteal) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'stolen',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${record.distanceMeters.toStringAsFixed(0)}m · ${(record.durationSeconds ~/ 60)}min · +${record.xpEarned} XP',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(record.capturedAt),
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
