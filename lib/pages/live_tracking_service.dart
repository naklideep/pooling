import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackingService {
  LiveTrackingService._private();
  static final LiveTrackingService instance = LiveTrackingService._private();

  StreamSubscription<Position>? _positionSub;
  String? _rideId;

  /// Start live tracking for the given rideId.
  /// Updates currentLocation object and lastUpdated timestamp.
  Future<void> start(
      String rideId, {
        LocationAccuracy accuracy = LocationAccuracy.best,
        int distanceFilter = 10,
      }) async {
    _rideId = rideId;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    _positionSub?.cancel();

    // When tracking starts, merge in tracking status safely
    await FirebaseFirestore.instance.collection('rides').doc(rideId).set({
      'status': 'tracking',
      'trackingStartedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter),
    ).listen((pos) async {
      if (_rideId == null) return;

      final loc = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'speed': pos.speed,
        'heading': pos.heading,
      };

      try {
        await FirebaseFirestore.instance.collection('rides').doc(_rideId).set({
          'currentLocation': loc,
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'in_progress',
        }, SetOptions(merge: true)); // ✅ merge instead of update
      } catch (e) {
        // Avoid crashes due to Firestore issues
        // ignore: avoid_print
        print('Error updating location: $e');
      }
    });
  }

  /// Stop tracking
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;

    if (_rideId != null) {
      await FirebaseFirestore.instance.collection('rides').doc(_rideId).set({
        'status': 'paused',
        'trackingStoppedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // ✅ Preserve all fields
    }

    _rideId = null;
  }

  /// Force-stop and optionally mark ride completed
  Future<void> stopAndComplete({String? rideId}) async {
    await stop();
    final id = rideId ?? _rideId;
    if (id != null) {
      try {
        await FirebaseFirestore.instance.collection('rides').doc(id).set({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // ✅ No field loss
      } catch (e) {
        // ignore: avoid_print
        print('Error completing ride: $e');
      }
    }
  }
}
