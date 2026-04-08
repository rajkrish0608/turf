import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/territory.dart';
import '../models/player.dart';
import '../models/game_stats.dart';
import 'geo_math.dart';

/// Abstract service interface — swap between Demo and Supabase implementations
abstract class TerritoryService {
  ValueNotifier<bool> get dataChanged;
  bool get isLoggedIn;
  Player get currentPlayer;
  GameStats get gameStats;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password, required String username});
  Future<void> signOut();

  List<Territory> get allTerritories;
  Future<Territory> captureTerritory({
    required List<LatLng> route,
    required int durationSeconds,
    required double distanceMeters,
    required String activityType,
  });
  Map<String, double> getLeaderboard(String timeFilter);
  List<Territory> getPlayerTerritories(String playerName);
  List<CaptureRecord> getCaptureHistory();

  // Profile
  void updateProfile({String? username, String? avatar});

  // Onboarding
  bool get hasSeenOnboarding;
  void markOnboardingSeen();
}

/// In-memory implementation with Supabase Auth
class DemoTerritoryService implements TerritoryService {
  static final DemoTerritoryService _instance = DemoTerritoryService._();
  factory DemoTerritoryService() => _instance;
  DemoTerritoryService._();

  @override
  final ValueNotifier<bool> dataChanged = ValueNotifier(false);

  bool _hasSeenOnboarding = false;

  Player _currentPlayer = const Player(
    username: 'Player',
    avatar: '😎',
  );

  final GameStats _gameStats = GameStats();

  final List<Territory> _territories = [
    Territory(
      id: 'demo-territory-1',
      ownerName: 'TurfRunner',
      color: '#58a6ff',
      areaSqm: 1500.0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      coordinates: [
        [70.8000, 22.3000],
        [70.8050, 22.3000],
        [70.8050, 22.3050],
        [70.8000, 22.3050],
        [70.8000, 22.3000],
      ],
    ),
  ];

  final List<Map<String, dynamic>> _auditLog = [];

  bool _isDemoLoggedIn = false;

  // Demo credentials
  static const _demoEmail = 'demo@turf.app';
  static const _demoPassword = 'demo1234';
  static const _demoUsername = 'TurfPlayer';

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _notify() {
    dataChanged.value = !dataChanged.value;
  }

  // --- Auth ---
  @override
  bool get isLoggedIn {
    if (_isDemoLoggedIn) return true;
    if (!_isSupabaseConfigured) return false;
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Player get currentPlayer {
    if (_isDemoLoggedIn) return _currentPlayer;
    if (!_isSupabaseConfigured) return _currentPlayer;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metadata = user.userMetadata;
        return Player(
          username: metadata?['username'] ?? user.email?.split('@').first ?? 'Player',
          avatar: metadata?['avatar'] ?? '😎',
        );
      }
    } catch (_) {}
    return _currentPlayer;
  }

  @override
  GameStats get gameStats => _gameStats;

  @override
  Future<void> signIn({required String email, required String password}) async {
    // Demo login — works without Supabase
    if (email.trim().toLowerCase() == _demoEmail && password == _demoPassword) {
      _isDemoLoggedIn = true;
      _currentPlayer = const Player(username: _demoUsername, avatar: '🏃');
      _notify();
      return;
    }

    if (!_isSupabaseConfigured) {
      throw Exception('Use demo@turf.app / demo1234 to sign in.');
    }

    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _currentPlayer = currentPlayer;
    _notify();
  }

  @override
  Future<void> signUp({required String email, required String password, required String username}) async {
    // Demo mode — just log them in
    if (!_isSupabaseConfigured) {
      _isDemoLoggedIn = true;
      _currentPlayer = Player(username: username, avatar: '🏃');
      _notify();
      return;
    }

    await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'avatar': '😎'},
    );
    _currentPlayer = Player(username: username, avatar: '😎');
    _notify();
  }

  @override
  Future<void> signOut() async {
    _isDemoLoggedIn = false;
    _currentPlayer = const Player(username: 'Player', avatar: '😎');
    if (_isSupabaseConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    _notify();
  }

  // --- Territories ---
  @override
  List<Territory> get allTerritories =>
      _territories.where((t) => !t.isDeleted && !t.isExpired).toList();

  @override
  Future<Territory> captureTerritory({
    required List<LatLng> route,
    required int durationSeconds,
    required double distanceMeters,
    required String activityType,
  }) async {
    // Validate in service layer — never trust client
    final validation = GeoMath.validateCapture(
      route: route,
      durationSeconds: durationSeconds,
      activityType: activityType,
    );
    if (validation != CaptureValidation.valid) {
      throw CaptureException(
        GeoMath.validationMessage(validation),
        validation,
      );
    }

    // 1. Simplify route
    final simplified = GeoMath.simplifyRoute(route);

    // 2. Calculate real polygon area
    final areaSqm = GeoMath.calculatePolygonAreaSqm(simplified);

    // 3. Build polygon coordinates (GeoJSON: [lng, lat])
    final coords = simplified
        .map((p) => [p.longitude, p.latitude])
        .toList();
    coords.add([simplified.first.longitude, simplified.first.latitude]);

    // 4. Check overlap against existing territories
    bool wasSteal = false;
    final playerName = currentPlayer.username;
    for (int i = _territories.length - 1; i >= 0; i--) {
      final existing = _territories[i];
      if (existing.isDeleted || existing.ownerName == playerName) {
        continue;
      }
      final existingCoords = existing.coordinates
          .map((c) => LatLng(c[1], c[0]))
          .toList();
      final overlap = GeoMath.checkOverlap(existingCoords, simplified);

      if (overlap == OverlapResult.stolen) {
        existing.isDeleted = true;
        wasSteal = true;
        _auditLog.add({
          'action': 'territory_stolen',
          'from': existing.ownerName,
          'by': playerName,
          'territory_id': existing.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      // Contested: existing territory coexists but is weakened
      // (In production, this would reduce the existing territory's area)
    }

    // 5. Create new territory
    final territory = Territory(
      id: '${DateTime.now().microsecondsSinceEpoch}-${playerName.hashCode.abs()}',
      ownerName: playerName,
      color: GeoMath.generatePlayerColor(playerName),
      areaSqm: areaSqm,
      createdAt: DateTime.now(),
      coordinates: coords,
    );

    _territories.add(territory);

    // 6. Award XP
    final xpEarned = _gameStats.addCaptureXP(
      distanceMeters: distanceMeters,
      areaSqm: areaSqm,
      isSteal: wasSteal,
    );

    // 7. Record history
    _gameStats.captureHistory.add(CaptureRecord(
      territoryId: territory.id,
      areaSqm: areaSqm,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      activityType: activityType,
      capturedAt: DateTime.now(),
      xpEarned: xpEarned,
      wasSteal: wasSteal,
    ));

    _notify();
    return territory;
  }

  @override
  Map<String, double> getLeaderboard(String timeFilter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<String, double> scores = {};

    for (final t in allTerritories) {
      bool include = false;

      switch (timeFilter) {
        case 'Daily':
          // Calendar day boundary
          final captureDay = DateTime(
              t.createdAt.year, t.createdAt.month, t.createdAt.day);
          include = captureDay == today;
          break;
        case 'Weekly':
          include = now.difference(t.createdAt).inDays <= 7;
          break;
        case 'Monthly':
          include = now.difference(t.createdAt).inDays <= 30;
          break;
        default:
          include = true;
      }

      if (include) {
        scores[t.ownerName] = (scores[t.ownerName] ?? 0) + t.effectiveArea;
      }
    }

    return scores;
  }

  @override
  List<Territory> getPlayerTerritories(String playerName) {
    return allTerritories.where((t) => t.ownerName == playerName).toList();
  }

  @override
  List<CaptureRecord> getCaptureHistory() {
    return List.from(_gameStats.captureHistory.reversed);
  }

  // --- Onboarding ---
  @override
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  @override
  void markOnboardingSeen() {
    _hasSeenOnboarding = true;
  }

  // --- Profile ---
  @override
  void updateProfile({String? username, String? avatar}) {
    final oldName = _currentPlayer.username;
    _currentPlayer = _currentPlayer.copyWith(
      username: username,
      avatar: avatar,
    );

    // Propagate username change to territory ownership
    if (username != null && username != oldName) {
      for (int i = 0; i < _territories.length; i++) {
        final t = _territories[i];
        if (t.ownerName == oldName) {
          _territories[i] = Territory(
            id: t.id,
            ownerName: username,
            color: t.color,
            areaSqm: t.areaSqm,
            createdAt: t.createdAt,
            coordinates: t.coordinates,
            isDeleted: t.isDeleted,
          );
        }
      }
    }
    _notify();
  }
}
