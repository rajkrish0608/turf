import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';

class TerritoryInfoSheet extends StatelessWidget {
  final Territory territory;

  const TerritoryInfoSheet({super.key, required this.territory});

  String _formatArea(double area) {
    if (area >= 1000) {
      return '${(area / 1000).toStringAsFixed(1)}K m²';
    }
    return '${area.toStringAsFixed(0)} m²';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Color _healthColor(double percent) {
    if (percent > 60) return AppTheme.success;
    if (percent > 30) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final health = territory.healthPercent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Owner
          Text(
            territory.ownerName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Captured ${_timeAgo(territory.createdAt)}',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Stats with health bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.surfaceContainer(),
            child: Column(
              children: [
                _row('Area', _formatArea(territory.effectiveArea)),
                const SizedBox(height: 10),
                // Health bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Health',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 13)),
                    Text(
                      '${health.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: _healthColor(health),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (health / 100).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.surfaceElevated,
                    valueColor:
                        AlwaysStoppedAnimation(_healthColor(health)),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 10),
                _row('Age', '${territory.daysSinceCapture}d'),
              ],
            ),
          ),

          // Decay info
          if (territory.areaSqm != territory.effectiveArea &&
              territory.effectiveArea > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.trending_down,
                    color: AppTheme.warning, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Decaying: ${_formatArea(territory.areaSqm)} → ${_formatArea(territory.effectiveArea)}',
                  style: const TextStyle(
                      color: AppTheme.warning, fontSize: 12),
                ),
              ],
            ),
          ],

          // Abandoned warning
          if (territory.isAbandoned && !territory.isExpired) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: AppTheme.danger, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Abandoned — will expire soon',
                  style:
                      TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}
