import 'dart:math' as math;

class GameStats {
  int totalXP;
  int totalCaptures;
  double totalDistanceMeters;
  int currentStreak;
  DateTime? lastCaptureDate;
  List<CaptureRecord> captureHistory;

  GameStats({
    this.totalXP = 0,
    this.totalCaptures = 0,
    this.totalDistanceMeters = 0,
    this.currentStreak = 0,
    this.lastCaptureDate,
    List<CaptureRecord>? captureHistory,
  }) : captureHistory = captureHistory ?? [];

  // --- Leveling System ---
  int get level => _xpToLevel(totalXP);
  String get title => _levelTitles[level.clamp(0, _levelTitles.length - 1)];
  int get xpToNextLevel => _levelThreshold(level + 1) - totalXP;
  double get levelProgress {
    final currentThreshold = _levelThreshold(level);
    final nextThreshold = _levelThreshold(level + 1);
    final range = nextThreshold - currentThreshold;
    if (range == 0) return 1.0;
    return ((totalXP - currentThreshold) / range).clamp(0.0, 1.0);
  }

  static int _xpToLevel(int xp) {
    for (int i = _thresholds.length - 1; i >= 0; i--) {
      if (xp >= _thresholds[i]) return i;
    }
    return 0;
  }

  static int _levelThreshold(int level) {
    if (level >= _thresholds.length) return _thresholds.last * 2;
    return _thresholds[level.clamp(0, _thresholds.length - 1)];
  }

  static const _thresholds = [
    0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500, 7500,
  ];

  static const _levelTitles = [
    'Recruit',
    'Scout',
    'Ranger',
    'Explorer',
    'Pathfinder',
    'Conqueror',
    'Commander',
    'General',
    'Overlord',
    'Warlord',
    'Sovereign',
  ];

  // --- Streak Logic ---
  void updateStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastCaptureDate != null) {
      final lastDate = DateTime(
        lastCaptureDate!.year,
        lastCaptureDate!.month,
        lastCaptureDate!.day,
      );
      final diff = today.difference(lastDate).inDays;
      if (diff == 0) {
        // Already captured today — streak unchanged
      } else if (diff == 1) {
        currentStreak++;
      } else {
        currentStreak = 1; // streak broken
      }
    } else {
      currentStreak = 1;
    }
    lastCaptureDate = now;
  }

  double get streakMultiplier => math.min(2.0, 1.0 + (currentStreak * 0.1));

  // --- XP Rewards ---
  int addCaptureXP({
    required double distanceMeters,
    required double areaSqm,
    bool isSteal = false,
  }) {
    int xp = 0;
    // Min 1 XP per 10m, but always at least 1 for any distance
    xp += math.max(1, (distanceMeters / 10).round());
    xp += 50; // base capture bonus
    if (isSteal) xp += 100; // steal bonus
    xp = (xp * streakMultiplier).round();
    totalXP += xp;
    totalCaptures++;
    totalDistanceMeters += distanceMeters;
    updateStreak();
    return xp;
  }

  /// XP earned in the last 7 days
  int get lastWeekXP {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    int sum = 0;
    for (final record in captureHistory) {
      if (record.capturedAt.isAfter(cutoff)) {
        sum += record.xpEarned;
      }
    }
    return sum;
  }
}

class CaptureRecord {
  final String territoryId;
  final double areaSqm;
  final double distanceMeters;
  final int durationSeconds;
  final String activityType;
  final DateTime capturedAt;
  final int xpEarned;
  final bool wasSteal;

  const CaptureRecord({
    required this.territoryId,
    required this.areaSqm,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.activityType,
    required this.capturedAt,
    required this.xpEarned,
    this.wasSteal = false,
  });
}
