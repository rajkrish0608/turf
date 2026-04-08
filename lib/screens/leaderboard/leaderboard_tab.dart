import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/territory_service.dart';

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});
  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  final _service = DemoTerritoryService();
  String _timeFilter = 'All Time';

  @override
  void initState() {
    super.initState();
    _service.dataChanged.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.dataChanged.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _formatArea(double area) {
    if (area >= 1000) {
      return '${(area / 1000).toStringAsFixed(1)}K';
    }
    return area.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final scores = _service.getLeaderboard(_timeFilter);
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final currentUser = _service.currentPlayer.username;

    int userRank = -1;
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].key == currentUser) {
        userRank = i;
        break;
      }
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Rankings',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children:
                  ['Daily', 'Weekly', 'Monthly', 'All Time'].map((f) {
                final isSelected = _timeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      f,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.background
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceElevated,
                    onSelected: (s) {
                      if (s) setState(() => _timeFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Your rank summary
          if (userRank >= 0)
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.primarySubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: AppTheme.background,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '#${userRank + 1}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatArea(sorted[userRank].value)} m²',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        'effective area',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Leaderboard list
          Expanded(
            child: sorted.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: sorted.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final entry = sorted[index];
                      final isCurrentUser = entry.key == currentUser;
                      final isTop3 = index < 3;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: isCurrentUser
                                ? const BorderSide(
                                    color: AppTheme.primary, width: 2)
                                : BorderSide.none,
                            bottom: const BorderSide(
                                color: AppTheme.borderColor,
                                width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isTop3
                                      ? AppTheme.gold
                                      : AppTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isCurrentUser
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${_formatArea(entry.value)} m²',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 32, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No territories captured yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeFilter == 'All Time'
                  ? 'Be the first to capture territory.'
                  : 'No captures in this time period.',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
