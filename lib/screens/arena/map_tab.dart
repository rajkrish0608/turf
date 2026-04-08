import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:location/location.dart';
import '../../theme/app_theme.dart';
import '../../services/territory_service.dart';
import '../../services/geo_math.dart';
import '../../widgets/countdown_overlay.dart';
import '../../widgets/celebration_dialog.dart';
import '../../widgets/territory_info_sheet.dart';
import '../../models/territory.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with SingleTickerProviderStateMixin {
  final _service = DemoTerritoryService();
  MapLibreMapController? mapController;
  Location location = Location();

  bool isTracking = false;
  bool showCountdown = false;
  bool showCelebration = false;
  bool _sourcesReady = false;
  List<LatLng> routeCoords = [];
  StreamSubscription<LocationData>? locationSubscription;

  double runDistance = 0.0;
  int runTimeSeconds = 0;
  Timer? runTimer;

  double? gpsAccuracy;
  Color get gpsColor {
    if (gpsAccuracy == null) return AppTheme.textMuted;
    if (gpsAccuracy! < 10) return AppTheme.success;
    if (gpsAccuracy! < 25) return AppTheme.gold;
    return AppTheme.danger;
  }

  String selectedActivity = 'Run';

  static const _mapTilerKey = String.fromEnvironment('MAP_TILER_KEY');
  String get styleUrl =>
      'https://api.maptiler.com/maps/dataviz-dark/style.json?key=$_mapTilerKey';

  Territory? _lastCapture;
  int _lastXpEarned = 0;
  bool _lastWasSteal = false;
  double _lastDistance = 0;
  int _lastDuration = 0;

  // Stats bar animation
  late final AnimationController _statsAnimController;
  late final Animation<Offset> _statsSlide;

  @override
  void initState() {
    super.initState();
    _service.dataChanged.addListener(_onDataChanged);

    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _statsSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statsAnimController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _service.dataChanged.removeListener(_onDataChanged);
    locationSubscription?.cancel();
    runTimer?.cancel();
    _statsAnimController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadTerritories();
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    _locateAndZoom();
  }

  void _onStyleLoaded() async {
    // Add sources and layers ONCE — update data via setGeoJsonSource thereafter
    try {
      await mapController!.addSource(
        'territories-source',
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );
      await mapController!.addFillLayer(
        'territories-source',
        'territories-fill',
        const FillLayerProperties(
          fillColor: ['get', 'color'],
          fillOpacity: 0.25,
        ),
      );
      await mapController!.addLineLayer(
        'territories-source',
        'territories-glow',
        const LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 2.0,
        ),
      );
      await mapController!.addSymbolLayer(
        'territories-source',
        'territories-label',
        const SymbolLayerProperties(
          textField: ['get', 'owner'],
          textColor: '#FFFFFF',
          textSize: 13.0,
        ),
      );
      await mapController!.addSource(
        'route-source',
        const GeojsonSourceProperties(
          data: {"type": "FeatureCollection", "features": []},
        ),
      );
      await mapController!.addLineLayer(
        'route-source',
        'route-line',
        const LineLayerProperties(lineColor: '#58a6ff', lineWidth: 3.0),
      );
      _sourcesReady = true;
      _loadTerritories();
    } catch (e) {
      debugPrint('Style load error: $e');
    }
  }

  Future<void> _locateAndZoom() async {
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }
      LocationData locData = await location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(locData.latitude!, locData.longitude!),
            zoom: 16.0,
            tilt: 45.0,
          ),
        ));
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadTerritories() async {
    if (mapController == null || !_sourcesReady) return;
    try {
      final territories = _service.allTerritories;
      List<Map<String, dynamic>> features = [];
      for (final t in territories) {
        features.add(t.toGeoJsonFeature());
      }
      // Update data in-place — no teardown/rebuild
      await mapController!.setGeoJsonSource('territories-source', {
        "type": "FeatureCollection",
        "features": features,
      });
    } catch (e) {
      debugPrint('Territory load error: $e');
    }
  }

  void _initiateStart() {
    HapticFeedback.lightImpact();
    setState(() => showCountdown = true);
  }

  void _startTracking() {
    setState(() {
      showCountdown = false;
      isTracking = true;
      routeCoords.clear();
      runDistance = 0.0;
      runTimeSeconds = 0;
    });
    _statsAnimController.forward();

    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => runTimeSeconds++);
    });

    locationSubscription = location.onLocationChanged.listen((locData) {
      if (locData.latitude != null && locData.longitude != null) {
        final newPoint = LatLng(locData.latitude!, locData.longitude!);
        setState(() {
          gpsAccuracy = locData.accuracy;
          if (routeCoords.isNotEmpty) {
            runDistance += GeoMath.haversine(routeCoords.last, newPoint);
          }
          routeCoords.add(newPoint);
        });
        _updateLiveRoute();
      }
    });
  }

  Future<void> _updateLiveRoute() async {
    if (mapController == null || routeCoords.length < 2 || !_sourcesReady) {
      return;
    }
    final coords =
        routeCoords.map((p) => [p.longitude, p.latitude]).toList();
    await mapController!.setGeoJsonSource('route-source', {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": coords}
        }
      ]
    });
  }

  Future<void> _stopAndCapture() async {
    setState(() => isTracking = false);
    _statsAnimController.reverse();
    locationSubscription?.cancel();
    runTimer?.cancel();

    if (routeCoords.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Run too short. Move more before capturing.'),
          ),
        );
      }
      return;
    }

    try {
      final territory = await _service.captureTerritory(
        route: routeCoords,
        durationSeconds: runTimeSeconds,
        distanceMeters: runDistance,
        activityType: selectedActivity,
      );

      HapticFeedback.heavyImpact();

      final history = _service.getCaptureHistory();
      final lastRecord = history.isNotEmpty ? history.first : null;

      setState(() {
        _lastCapture = territory;
        _lastXpEarned = lastRecord?.xpEarned ?? 50;
        _lastWasSteal = lastRecord?.wasSteal ?? false;
        _lastDistance = runDistance;
        _lastDuration = runTimeSeconds;
        showCelebration = true;
      });

      _clearRoute();
      _loadTerritories();
    } on CaptureException catch (e) {
      HapticFeedback.vibrate();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Capture rejected'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      _clearRoute();
    } catch (error) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Capture failed'),
            content: Text('Error: $error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _clearRoute() {
    routeCoords.clear();
    setState(() {
      runDistance = 0.0;
      runTimeSeconds = 0;
    });
    if (_sourcesReady) {
      mapController?.setGeoJsonSource('route-source', {
        "type": "FeatureCollection",
        "features": [],
      });
    }
  }

  void _onFeatureTapped(Point<double> point, LatLng coordinates) {
    final territories = _service.allTerritories;
    Territory? tapped;
    for (final t in territories) {
      final polyCoords =
          t.coordinates.map((c) => LatLng(c[1], c[0])).toList();
      if (GeoMath.isPointInPolygon(coordinates, polyCoords)) {
        tapped = t;
        break;
      }
    }
    if (tapped != null && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => TerritoryInfoSheet(territory: tapped!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map
        MapLibreMap(
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          styleString: styleUrl,
          initialCameraPosition: const CameraPosition(
            target: LatLng(20.0, 0.0),
            zoom: 2.0,
          ),
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
          onMapClick: _onFeatureTapped,
        ),

        // Top bar — opaque, no glassmorphism
        Positioned(
          top: 50,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                // Activity selector
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedActivity,
                      dropdownColor: AppTheme.surfaceElevated,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      items: GeoMath.speedLimits.keys
                          .map((v) => DropdownMenuItem(
                              value: v, child: Text(v)))
                          .toList(),
                      onChanged: isTracking
                          ? null
                          : (v) =>
                              setState(() => selectedActivity = v!),
                    ),
                  ),
                ),

                const Spacer(),

                // GPS quality indicator (6px dot)
                if (isTracking)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: gpsColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Stats during tracking — slides up
        if (isTracking)
          Positioned(
            bottom: 96,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _statsSlide,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${runDistance.toStringAsFixed(0)} m',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('Distance',
                            style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11)),
                      ],
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        color: AppTheme.borderColor),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(runTimeSeconds ~/ 60).toString().padLeft(2, '0')}:${(runTimeSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('Time',
                            style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Start/Stop — fixed position
        Positioned(
          bottom: 28,
          left: 32,
          right: 32,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isTracking ? _stopAndCapture : _initiateStart,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isTracking ? AppTheme.danger : AppTheme.primary,
                foregroundColor:
                    isTracking ? Colors.white : AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radius),
                ),
              ),
              child: Text(
                isTracking
                    ? 'Stop and capture'
                    : 'Start $selectedActivity',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),

        // Countdown
        if (showCountdown) CountdownOverlay(onComplete: _startTracking),

        // Celebration
        if (showCelebration && _lastCapture != null)
          CelebrationDialog(
            areaSqm: _lastCapture!.areaSqm,
            xpEarned: _lastXpEarned,
            wasSteal: _lastWasSteal,
            activityType: selectedActivity,
            distanceMeters: _lastDistance,
            durationSeconds: _lastDuration,
            gameStats: _service.gameStats,
            onDismiss: () => setState(() => showCelebration = false),
          ),
      ],
    );
  }
}
