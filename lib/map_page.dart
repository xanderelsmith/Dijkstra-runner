import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:confetti/confetti.dart';
import 'dart:convert';
import 'dart:math' as math;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;
  String? _routeDistance;
  String? _routeDuration;

  // Car animation
  AnimationController? _carAnimationController;
  LatLng? _carPosition;
  double _carBearing = 0.0; // Rotation angle in degrees
  bool _isAnimating = false;

  // Confetti celebration
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController();
    _carAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 30,
      ), // Default 30 seconds for full route
    );
    _carAnimationController!.addListener(_updateCarPosition);
  }

  @override
  void dispose() {
    _carAnimationController?.dispose();
    super.dispose();
  }

  void _updateCarPosition() {
    if (_routePoints.isEmpty || _startPoint == null) return;

    final progress = _carAnimationController!.value.clamp(0.0, 1.0);

    final fullRoute = [_startPoint!, ..._routePoints];
    final totalSegments = fullRoute.length - 1;

    if (totalSegments <= 0) return;

    final segmentIndex = (progress * totalSegments).floor();
    final segmentProgress = (progress * totalSegments) - segmentIndex;

    final currentIndex = math.min(segmentIndex, fullRoute.length - 1);
    final nextIndex = math.min(segmentIndex + 1, fullRoute.length - 1);

    final currentPoint = fullRoute[currentIndex];
    final nextPoint = fullRoute[nextIndex];

    // Interpolate position
    final lat =
        currentPoint.latitude +
        (nextPoint.latitude - currentPoint.latitude) * segmentProgress;
    final lng =
        currentPoint.longitude +
        (nextPoint.longitude - currentPoint.longitude) * segmentProgress;

    setState(() {
      _carPosition = LatLng(lat, lng);
      // Calculate bearing (direction) for car rotation
      _carBearing = _calculateBearing(currentPoint, nextPoint);
    });

    // Keep map centered on car
    _mapController.move(_carPosition!, _mapController.camera.zoom);
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  void _startCarAnimation() {
    if (_routePoints.isEmpty || _startPoint == null) return;

    setState(() {
      _carPosition = _startPoint;
      _isAnimating = true;
    });

    // Calculate animation duration based on route distance
    // Rough estimate: 30 seconds per 10km, minimum 5 seconds
    final distanceKm =
        double.tryParse(_routeDistance?.replaceAll(' km', '') ?? '0') ?? 0;
    final durationSeconds = math.max(5, (distanceKm / 10 * 30).round());

    _carAnimationController!.duration = Duration(seconds: durationSeconds);
    _carAnimationController!.forward(from: 0).then((_) {
      // Animation completed - celebrate!
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
        _confettiController.play();
      }
    });
  }

  void _stopCarAnimation() {
    _carAnimationController?.stop();
    setState(() {
      _isAnimating = false;
    });
  }

  void _resetCarAnimation() {
    _carAnimationController?.reset();
    _confettiController.stop();
    setState(() {
      _carPosition = null;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-World Navigation'),
        backgroundColor: const Color(0xff1e293b),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(
                51.509364,
                -0.128928,
              ), // London default
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() {
                  if (_startPoint == null) {
                    _startPoint = point;
                  } else if (_endPoint == null) {
                    _endPoint = point;
                    _calculateRoute();
                  } else {
                    // Reset and set new start
                    _startPoint = point;
                    _endPoint = null;
                    _routePoints = [];
                    _routeDistance = null;
                    _routeDuration = null;
                    _resetCarAnimation();
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dijkstra_runner',
              ),
              // Draw route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: const Color(0xff3b82f6),
                    ),
                  ],
                ),
              // Markers for start/end points and car
              MarkerLayer(
                markers: [
                  if (_startPoint != null)
                    Marker(
                      point: _startPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  if (_endPoint != null)
                    Marker(
                      point: _endPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  // Car marker
                  if (_carPosition != null)
                    Marker(
                      point: _carPosition!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: Transform.rotate(
                        angle: _carBearing * math.pi / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xfff59e0b),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          // Route info card
          if (_routeDistance != null && _routeDuration != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: const Color(0xff334155),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distance: $_routeDistance',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Duration: $_routeDuration',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Instructions card
          if (_startPoint == null || _endPoint == null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                color: const Color(0xff334155),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _startPoint == null
                        ? 'Tap on the map to set start point'
                        : 'Tap on the map to set end point',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          // Confetti celebration
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // Upward
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.red,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'clear_route',
            onPressed: () {
              _resetCarAnimation();
              setState(() {
                _startPoint = null;
                _endPoint = null;
                _routePoints = [];
                _routeDistance = null;
                _routeDuration = null;
              });
            },
            backgroundColor: const Color(0xff6b7280),
            child: const Icon(Icons.clear),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'refresh_route',
            onPressed: () {
              if (_startPoint != null && _endPoint != null) {
                _resetCarAnimation();
                _calculateRoute();
              }
            },
            backgroundColor: const Color(0xff3b82f6),
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          // Car animation control button
          if (_routePoints.isNotEmpty)
            FloatingActionButton(
              heroTag: 'car_animation',
              onPressed: () {
                if (_isAnimating) {
                  _stopCarAnimation();
                } else {
                  _startCarAnimation();
                }
              },
              backgroundColor: _isAnimating
                  ? const Color(0xffef4444)
                  : const Color(0xff10b981),
              child: Icon(_isAnimating ? Icons.stop : Icons.play_arrow),
            ),
        ],
      ),
    );
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() => _isLoading = true);

    try {
      // Using OSRM routing API (free, no API key needed)
      // This uses Dijkstra's algorithm on the OpenStreetMap road network
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_startPoint!.longitude},${_startPoint!.latitude};'
        '${_endPoint!.longitude},${_endPoint!.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'];

          // Calculate distance and duration
          final distance = route['distance'] / 1000; // Convert to km
          final duration = route['duration'] / 60; // Convert to minutes

          setState(() {
            _routePoints = (geometry as List)
                .map(
                  (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
                )
                .toList();
            _routeDistance = '${distance.toStringAsFixed(2)} km';
            _routeDuration = '${duration.toStringAsFixed(1)} min';
            _isLoading = false;
            // Reset car animation when new route is calculated
            _resetCarAnimation();
          });

          // Fit map to show entire route
          if (_routePoints.isNotEmpty) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(_routePoints),
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No route found between these points'),
              ),
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating route: $e')));
      }
    }
  }
}
