import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'live_tracking_service.dart';
import 'rating_dialog.dart';

class LiveRideTrackingPage extends StatefulWidget {
  final String rideId;
  final double startLat;
  final double startLng;
  final double destLat;
  final double destLng;
  final bool isDriver;

  const LiveRideTrackingPage({
    super.key,
    required this.rideId,
    required this.startLat,
    required this.startLng,
    required this.destLat,
    required this.destLng,
    required this.isDriver,
  });

  @override
  State<LiveRideTrackingPage> createState() => _LiveRideTrackingPageState();
}

class _LiveRideTrackingPageState extends State<LiveRideTrackingPage> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _driverPos;
  bool _isTracking = false;
  Stream<DocumentSnapshot>? _rideStream;

  @override
  void initState() {
    super.initState();
    _rideStream = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots();
    _fetchRoute();

    _checkTrackingStatus();
  }

  Future<void> _checkTrackingStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isTracking'] == true) {
          setState(() => _isTracking = true);
        }
      }
    } catch (e) {
      debugPrint("Error checking tracking status: $e");
    }
  }

  Future<void> _fetchRoute() async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${widget.startLng},${widget.startLat};${widget.destLng},${widget.destLat}?overview=full&geometries=geojson';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords
              .map((c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ))
              .toList();
        });

        if (_routePoints.isNotEmpty) {
          final latAvg = _routePoints.map((p) => p.latitude).reduce((a, b) => a + b) / _routePoints.length;
          final lngAvg = _routePoints.map((p) => p.longitude).reduce((a, b) => a + b) / _routePoints.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(LatLng(latAvg, lngAvg), 12);
          });
        }
      }
    } catch (e) {
      debugPrint("Route fetch error: $e");
    }
  }

  Future<void> _startDriverTracking() async {
    try {
      await LiveTrackingService.instance.start(widget.rideId);

      // 🔥 changed from update() → set(..., merge:true)
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .set({
        'isTracking': true,
        'trackingStartedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isTracking = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tracking started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start tracking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopDriverTracking() async {
    try {
      await LiveTrackingService.instance.stop();

      // 🔥 changed from update() → set(..., merge:true)
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .set({
        'isTracking': false,
        'trackingStoppedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isTracking = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸️ Tracking stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error stopping tracking: $e");
    }
  }

  Future<void> _markRideCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Complete Ride?"),
        content: const Text(
          "Are you sure you want to mark this ride as completed?\n\n"
              "Both driver and rider must confirm for the ride to be fully completed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
      final doc = await rideRef.get();

      if (!doc.exists) {
        _showError("Ride not found");
        return;
      }

      final data = doc.data()!;
      final posterCompleted = data['posterCompleted'] ?? false;
      final accepterCompleted = data['accepterCompleted'] ?? false;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showError("User not logged in");
        return;
      }

      final riderId = data['riderId'];
      final isPoster = riderId == currentUser.uid;

      if ((isPoster && posterCompleted) || (!isPoster && accepterCompleted)) {
        _showInfo("You've already marked this ride as completed.");
        return;
      }

      await rideRef.update({
        isPoster ? 'posterCompleted' : 'accepterCompleted': true,
      });

      final updatedDoc = await rideRef.get();
      final updated = updatedDoc.data()!;

      final bothCompleted = (updated['posterCompleted'] ?? false) &&
          (updated['accepterCompleted'] ?? false);

      if (bothCompleted) {
        await rideRef.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'isTracking': false,
        });

        await LiveTrackingService.instance.stop();

        _showSuccess("✅ Ride successfully completed by both parties!");

        final otherUserId = isPoster
            ? (updated['acceptedBy'] ?? (updated['acceptedByList'] as List?)?.first)
            : updated['riderId'];
        final otherUserName = isPoster
            ? (updated['acceptedByName'] ?? 'Your Rider')
            : (updated['postedByName'] ?? 'Your Driver');

        if (otherUserId != null && mounted) {
          await showRatingDialog(
            context: context,
            ratedUserId: otherUserId.toString(),
            ratedUserName: otherUserName.toString(),
            rideId: widget.rideId,
            currentUserId: currentUser.uid,
          );
        }

        if (mounted) Navigator.pop(context);
      } else {
        _showSuccess(
          isPoster
              ? "Marked as completed. Waiting for the rider to confirm..."
              : "Marked as completed. Waiting for the driver to confirm...",
        );
      }
    } catch (e) {
      _showError("Failed to mark ride as completed: $e");
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startPoint = LatLng(widget.startLat, widget.startLng);
    final destPoint = LatLng(widget.destLat, widget.destLng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDriver ? 'Live Tracking (Driver)' : 'Live Tracking (Rider)'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _rideStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final currentUser = FirebaseAuth.instance.currentUser;
          final riderId = data['riderId'];
          final acceptedBy = data['acceptedBy'];
          final acceptedByList = (data['acceptedByList'] as List?)?.map((e) => e.toString()).toList() ?? [];

          final isParticipant = currentUser != null && (
            currentUser.uid == riderId ||
            currentUser.uid == acceptedBy ||
            acceptedByList.contains(currentUser.uid)
          );

          if (!isParticipant) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.security, size: 48, color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      'Access Restricted',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Live GPS tracking is only accessible to confirmed participants of this ride.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final current = data['currentLocation'] as Map<String, dynamic>?;

          if (current != null) {
            final lat = (current['lat'] as num?)?.toDouble();
            final lng = (current['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _driverPos = LatLng(lat, lng);
            }
          }

          final status = data['status'] ?? 'pending';
          final distanceKm = data['distance_km'];
          final durationMin = data['duration_min'];
          final isTrackingActive = data['isTracking'] ?? false;
          final posterCompleted = data['posterCompleted'] ?? false;
          final accepterCompleted = data['accepterCompleted'] ?? false;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverPos ?? startPoint,
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.pooling',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: startPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                      Marker(
                        point: destPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.flag,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      if (_driverPos != null)
                        Marker(
                          point: _driverPos!,
                          width: 50,
                          height: 50,
                          child: Transform.rotate(
                            angle: ((current?['heading'] as num?)?.toDouble() ?? 0.0) * (math.pi / 180),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2340),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFFCC00), width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Color(0xFFFFCC00),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Info card at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 20,
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${status.toUpperCase()}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (distanceKm != null)
                                  Text('Distance: ${distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12)),
                                if (durationMin != null)
                                  Text('Duration: ${durationMin.toStringAsFixed(0)} min', style: const TextStyle(fontSize: 12)),
                                Text(
                                  isTrackingActive ? '🟢 Live tracking active' : '🔴 Tracking inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isTrackingActive ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (!widget.isDriver && _driverPos != null)
                              IconButton(
                                onPressed: () => _mapController.move(_driverPos!, 15),
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Center on driver',
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        if (posterCompleted || accepterCompleted) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    posterCompleted && accepterCompleted
                                        ? 'Both parties marked complete!'
                                        : posterCompleted
                                        ? 'Driver marked complete. Waiting for rider...'
                                        : 'Rider marked complete. Waiting for driver...',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        if (widget.isDriver)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isTracking ? _stopDriverTracking : _startDriverTracking,
                                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                                  label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isTracking ? Colors.orange : Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _markRideCompleted,
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Complete'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _markRideCompleted,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Mark as Complete'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
