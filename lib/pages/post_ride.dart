import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'enhanced_map_picker.dart';

// ─────────────────────────────────────────────
// Shared model — imported by SavedRoutesPage too
// ─────────────────────────────────────────────
class SavedRoute {
  final String id;
  final String fromAddress;
  final String toAddress;
  final LatLng? fromCoords; // null for FAB-added (text-only) routes
  final LatLng? toCoords;
  final DateTime savedAt;
  final int usageCount;
  final bool isFavourite;
  final String? nickname;
  final String? mode;
  final String? time;

  SavedRoute({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    this.fromCoords,
    this.toCoords,
    required this.savedAt,
    this.usageCount = 0,
    this.isFavourite = false,
    this.nickname,
    this.mode,
    this.time,
  });

  /// True only for routes saved from PostRidePage (have lat/lng).
  bool get hasCoords => fromCoords != null && toCoords != null;

  factory SavedRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    LatLng? fromCoords;
    LatLng? toCoords;
    if (d['from_lat'] != null && d['from_lng'] != null) {
      fromCoords = LatLng(
        (d['from_lat'] as num).toDouble(),
        (d['from_lng'] as num).toDouble(),
      );
    }
    if (d['to_lat'] != null && d['to_lng'] != null) {
      toCoords = LatLng(
        (d['to_lat'] as num).toDouble(),
        (d['to_lng'] as num).toDouble(),
      );
    }

    final savedAt = d['savedAt'] != null
        ? (d['savedAt'] as Timestamp).toDate()
        : d['createdAt'] != null
        ? (d['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return SavedRoute(
      id: doc.id,
      fromAddress: d['fromAddress'] ?? d['from'] ?? '',
      toAddress: d['toAddress'] ?? d['to'] ?? '',
      fromCoords: fromCoords,
      toCoords: toCoords,
      savedAt: savedAt,
      usageCount: d['usageCount'] ?? 0,
      isFavourite: d['isFavourite'] ?? false,
      nickname: d['nickname'],
      mode: d['mode'],
      time: d['time'],
    );
  }

  Map<String, dynamic> toMap() => {
    'fromAddress': fromAddress,
    'toAddress': toAddress,
    if (fromCoords != null) 'from_lat': fromCoords!.latitude,
    if (fromCoords != null) 'from_lng': fromCoords!.longitude,
    if (toCoords != null) 'to_lat': toCoords!.latitude,
    if (toCoords != null) 'to_lng': toCoords!.longitude,
    'usageCount': usageCount,
    'isFavourite': isFavourite,
    if (nickname != null) 'nickname': nickname,
    if (mode != null) 'mode': mode,
    if (time != null) 'time': time,
    'savedAt': FieldValue.serverTimestamp(),
  };
}

// ─────────────────────────────────────────────
// PostRidePage
// ─────────────────────────────────────────────
class PostRidePage extends StatefulWidget {
  /// Pass a [SavedRoute] when navigating from SavedRoutesPage to pre-fill fields.
  final SavedRoute? prefilledRoute;

  const PostRidePage({super.key, this.prefilledRoute});

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController();

  LatLng? _fromCoords;
  LatLng? _toCoords;
  DateTime? _selectedDateTime;
  final MapController _mapController = MapController();

  bool _isLoading = false;
  bool _loadingMap = true;
  bool _calculatingRoute = false;
  bool _savingRoute = false;
  String? _selectedRideType = "Car";
  bool _allowMultiple = true;

  double? _distanceKm;
  double? _durationMin;
  List<LatLng> _routePoints = [];

  List<SavedRoute> _savedRoutes = [];
  bool _loadingSavedRoutes = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ── Firestore ref ──────────────────────────
  CollectionReference get _routesRef {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_routes');
  }

  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    if (widget.prefilledRoute != null) {
      _applyPrefilledRoute(widget.prefilledRoute!);
    } else {
      _autoDetectCurrentLocation();
    }
    _loadSavedRoutes();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _seatsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // Pre-fill from SavedRoutesPage
  // ─────────────────────────────────────────

  void _applyPrefilledRoute(SavedRoute route) {
    _fromController.text = route.fromAddress;
    _toController.text = route.toAddress;
    _fromCoords = route.fromCoords;
    _toCoords = route.toCoords;
    setState(() => _loadingMap = false);

    if (route.hasCoords) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateRouteInfo();
      });
    }
  }

  // ─────────────────────────────────────────
  // Saved Routes CRUD
  // ─────────────────────────────────────────

  Future<void> _loadSavedRoutes() async {
    try {
      final snap =
      await _routesRef.orderBy('usageCount', descending: true).get();
      setState(() {
        _savedRoutes = snap.docs
            .map((d) => SavedRoute.fromFirestore(d))
            .where((r) => r.hasCoords) // chips only for map-capable routes
            .toList();
        _loadingSavedRoutes = false;
      });
    } catch (e) {
      debugPrint("Failed to load saved routes: $e");
      setState(() => _loadingSavedRoutes = false);
    }
  }

  Future<void> _saveCurrentRoute() async {
    if (_fromCoords == null || _toCoords == null) {
      _showError("Select both locations before saving");
      return;
    }

    final isDuplicate = _savedRoutes.any((r) =>
    r.fromCoords != null &&
        r.toCoords != null &&
        (r.fromCoords!.latitude - _fromCoords!.latitude).abs() < 0.001 &&
        (r.fromCoords!.longitude - _fromCoords!.longitude).abs() < 0.001 &&
        (r.toCoords!.latitude - _toCoords!.latitude).abs() < 0.001 &&
        (r.toCoords!.longitude - _toCoords!.longitude).abs() < 0.001);

    if (isDuplicate) {
      _showError("This route is already saved!");
      return;
    }

    setState(() => _savingRoute = true);
    try {
      final route = SavedRoute(
        id: '',
        fromAddress: _fromController.text.trim(),
        toAddress: _toController.text.trim(),
        fromCoords: _fromCoords,
        toCoords: _toCoords,
        savedAt: DateTime.now(),
      );

      final doc = await _routesRef.add(route.toMap());

      setState(() => _savedRoutes.insert(
        0,
        SavedRoute(
          id: doc.id,
          fromAddress: route.fromAddress,
          toAddress: route.toAddress,
          fromCoords: route.fromCoords,
          toCoords: route.toCoords,
          savedAt: route.savedAt,
        ),
      ));

      _showSuccess("Route saved!");
    } catch (e) {
      _showError("Failed to save route: ${e.toString()}");
    } finally {
      setState(() => _savingRoute = false);
    }
  }

  Future<void> _deleteSavedRoute(SavedRoute route) async {
    try {
      await _routesRef.doc(route.id).delete();
      setState(() => _savedRoutes.removeWhere((r) => r.id == route.id));
      _showSuccess("Route removed");
    } catch (e) {
      _showError("Failed to delete: ${e.toString()}");
    }
  }

  void _applySavedRoute(SavedRoute route) {
    if (!route.hasCoords) return;
    setState(() {
      _fromController.text = route.fromAddress;
      _toController.text = route.toAddress;
      _fromCoords = route.fromCoords;
      _toCoords = route.toCoords;
    });
    _calculateRouteInfo();

    // Increment usage count — reflects in SavedRoutesPage instantly (StreamBuilder)
    _routesRef.doc(route.id).update({
      'usageCount': FieldValue.increment(1),
      'lastUsed': FieldValue.serverTimestamp(),
    });

    _showSuccess("Route loaded!");
  }

  // ─────────────────────────────────────────
  // Location & Route
  // ─────────────────────────────────────────

  Future<void> _autoDetectCurrentLocation() async {
    setState(() => _loadingMap = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled.");
        setState(() => _loadingMap = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission denied.");
          setState(() => _loadingMap = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError("Location permission permanently denied.");
        setState(() => _loadingMap = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _fromController.text =
          address.isNotEmpty ? address : "Current Location";
          _fromCoords = LatLng(pos.latitude, pos.longitude);
          _loadingMap = false;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted)
            _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
        });

        _showSuccess("Location detected!");
      }
    } catch (e) {
      _showError("Failed to detect location.");
      setState(() => _loadingMap = false);
    }
  }

  Future<void> _calculateRouteInfo() async {
    if (_fromCoords == null || _toCoords == null) return;
    setState(() {
      _calculatingRoute = true;
      _routePoints.clear();
      _distanceKm = null;
      _durationMin = null;
    });

    try {
      final url = Uri.parse(
          "https://router.project-osrm.org/route/v1/driving/${_fromCoords!.longitude},${_fromCoords!.latitude};${_toCoords!.longitude},${_toCoords!.latitude}?overview=full&geometries=geojson");
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          throw Exception("No route found");
        }
        final route = data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;
        setState(() {
          _distanceKm = route['distance'] / 1000;
          _durationMin = route['duration'] / 60;
          _routePoints = coords
              .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
        });

        if (_routePoints.isNotEmpty && mounted) {
          final bounds = LatLngBounds.fromPoints(_routePoints);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted)
              _mapController.fitCamera(CameraFit.bounds(
                  bounds: bounds, padding: const EdgeInsets.all(50)));
          });
        }
      }
    } catch (e) {
      _showError("Failed to calculate route.");
    } finally {
      setState(() => _calculatingRoute = false);
    }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      final address = result['address'] as String?;
      final coords = result['latLng'] as LatLng?;
      if (address != null && coords != null) {
        setState(() {
          _toController.text = address;
          _toCoords = coords;
        });
        await _calculateRouteInfo();
      }
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF1E3C72), onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF1E3C72), onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() => _selectedDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate()) {
      _showError("Please fill all required fields");
      return;
    }
    if (_selectedDateTime == null) {
      _showError("Please select date and time");
      return;
    }
    if (_fromCoords == null || _toCoords == null) {
      _showError("Please select both pickup and destination locations");
      return;
    }
    if (_selectedDateTime!.isBefore(DateTime.now())) {
      _showError("Please select a future date and time");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String userName = "Unknown";
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        userName = userDoc['name'];
      } else if (user.displayName?.isNotEmpty ?? false) {
        userName = user.displayName!;
      } else if (user.email?.contains('@') ?? false) {
        userName = user.email!.split('@').first;
      }

      final seats = int.tryParse(_seatsController.text.trim()) ?? 1;
      final estCost = (_distanceKm != null ? _distanceKm! * 3 : 20) * seats;

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'from_lat': _fromCoords!.latitude,
        'from_lng': _fromCoords!.longitude,
        'to_lat': _toCoords!.latitude,
        'to_lng': _toCoords!.longitude,
        'seats': seats,
        'remainingSeats': seats,
        'rideType': _selectedRideType,
        'allowMultiple': _allowMultiple,
        'distance_km': _distanceKm,
        'duration_min': _durationMin,
        'estimatedCost': estCost.round(),
        'dateTime': _selectedDateTime,
        'status': 'pending',
        'riderId': user.uid,
        'postedByName': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSuccess("✅ Ride posted successfully!");
      _formKey.currentState!.reset();
      _fromController.clear();
      _toController.clear();
      _seatsController.clear();

      setState(() {
        _selectedDateTime = null;
        _fromCoords = null;
        _toCoords = null;
        _distanceKm = null;
        _durationMin = null;
        _routePoints.clear();
        _selectedRideType = "Car";
        _allowMultiple = true;
      });

      _autoDetectCurrentLocation();
    } catch (e) {
      _showError("❌ Error posting ride: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────
  // Snackbars
  // ─────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateTimeText = _selectedDateTime == null
        ? "Pick Date & Time"
        : DateFormat('MMM dd, yyyy • hh:mm a').format(_selectedDateTime!);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3C72),
                  Color(0xFF2A5298),
                  Color(0xFF7E22CE),
                ],
              ),
            ),
          ),

          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App Bar ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        )

                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text("Post a Ride",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      // "Saved" badge when pre-filled from SavedRoutesPage
                      if (widget.prefilledRoute != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.amberAccent.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark,
                                  color: Colors.amberAccent, size: 14),
                              SizedBox(width: 4),
                              Text("Saved",
                                  style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          tooltip: 'Detect current location',
                          onPressed:
                          _loadingMap ? null : _autoDetectCurrentLocation,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main Content ────────────────────────────
                Expanded(
                  child: _loadingMap
                      ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                          SizedBox(height: 20),
                          Text("Detecting your location...",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                      : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Saved route chips (only map-capable routes)
                          if (!_loadingSavedRoutes &&
                              _savedRoutes.isNotEmpty) ...[
                            _buildSavedRoutesSection(),
                            const SizedBox(height: 20),
                          ],

                          _buildInfoCard(
                            icon: widget.prefilledRoute != null
                                ? Icons.bookmark_rounded
                                : Icons.info_outline,
                            text: widget.prefilledRoute != null
                                ? "Loaded from saved route. Adjust if needed."
                                : "Your current location is auto-detected. Just select your destination!",
                            color: widget.prefilledRoute != null
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _fromController,
                            label: "From (Your Current Location)",
                            icon: Icons.my_location,
                            iconColor: Colors.greenAccent,
                            readOnly: true,
                            helperText: "Tap refresh icon to re-detect",
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _toController,
                            label: "Where do you want to go?",
                            icon: Icons.location_on,
                            iconColor: Colors.redAccent,
                            readOnly: true,
                            helperText: "Tap icon to select destination",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.map,
                                  color: Colors.white),
                              onPressed: _pickDestination,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_calculatingRoute)
                            _buildInfoCard(
                              icon: Icons.sync,
                              text: "Calculating route...",
                              color: Colors.orange.withOpacity(0.2),
                              showProgress: true,
                            )
                          else if (_distanceKm != null &&
                              _durationMin != null) ...[
                            _buildRouteInfoCard(),
                            const SizedBox(height: 12),
                            _buildSaveRouteButton(),
                          ],

                          if (_calculatingRoute ||
                              (_distanceKm != null && _durationMin != null))
                            const SizedBox(height: 20),

                          _buildDropdownField(),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _seatsController,
                            label: "Available Seats",
                            icon: Icons.event_seat,
                            iconColor: Colors.amber,
                            keyboardType: TextInputType.number,
                            enabled: _selectedRideType == "Car",
                            helperText: _selectedRideType == "Bike"
                                ? "1 (fixed)"
                                : "Max 6",
                            onChanged: (_) {
                              if (_distanceKm != null) setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildSwitchCard(),
                          const SizedBox(height: 20),

                          _buildDateTimeButton(dateTimeText),
                          const SizedBox(height: 20),

                          if (_fromCoords != null) _buildMapPreview(),
                          if (_fromCoords != null)
                            const SizedBox(height: 24),

                          _buildPostButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                      SizedBox(height: 20),
                      Text("Posting your ride...",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Saved Routes Widgets
  // ─────────────────────────────────────────

  Widget _buildSavedRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.bookmark, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text("Saved Routes",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text("${_savedRoutes.length}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _savedRoutes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _buildRouteChip(_savedRoutes[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteChip(SavedRoute route) {
    String shorten(String addr) {
      final parts = addr.split(',');
      final first = parts.first.trim();
      return first.length > 18 ? '${first.substring(0, 16)}…' : first;
    }

    // Highlight chip if it's the currently active route
    final isActive = _fromCoords != null &&
        _toCoords != null &&
        route.fromCoords != null &&
        route.toCoords != null &&
        (route.fromCoords!.latitude - _fromCoords!.latitude).abs() < 0.001 &&
        (route.toCoords!.latitude - _toCoords!.latitude).abs() < 0.001;

    return GestureDetector(
      onTap: () => _applySavedRoute(route),
      onLongPress: () => _showDeleteConfirmDialog(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.28)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.8)
                : Colors.white.withOpacity(0.3),
            width: isActive ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    color: Colors.greenAccent, size: 12),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    route.nickname?.isNotEmpty == true
                        ? route.nickname!
                        : shorten(route.fromAddress),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Container(
                  width: 1,
                  height: 10,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.white.withOpacity(0.4)),
            ),
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Colors.redAccent, size: 12),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    shorten(route.toAddress),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showDeleteConfirmDialog(route),
                  child: Icon(Icons.close,
                      color: Colors.white.withOpacity(0.5), size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(SavedRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3C72),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Route?",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Remove route from ${route.fromAddress.split(',').first} → ${route.toAddress.split(',').first}?",
          style:
          TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSavedRoute(route);
            },
            child:
            const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveRouteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _savingRoute ? null : _saveCurrentRoute,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
        icon: _savingRoute
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.bookmark_add_outlined, size: 20),
        label: Text(
          _savingRoute ? "Saving..." : "Save this Route",
          style:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Form Widgets
  // ─────────────────────────────────────────

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
    required Color color,
    bool showProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (showProgress)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
          else
            Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    final seats = int.tryParse(_seatsController.text) ?? 1;
    final estCost = (_distanceKm! * 3) * seats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoChip(Icons.straighten,
              "${_distanceKm!.toStringAsFixed(1)} km", "Distance"),
          Container(
              width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildInfoChip(Icons.schedule,
              "${_durationMin!.toStringAsFixed(0)} min", "Duration"),
          Container(
              width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildInfoChip(Icons.currency_rupee,
              "₹${estCost.toStringAsFixed(0)}", "Est. Cost"),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style:
            TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? iconColor,
    bool readOnly = false,
    bool enabled = true,
    String? helperText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border:
            Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            enabled: enabled,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(
                color: enabled
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontSize: 16),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 15),
              prefixIcon: Icon(icon,
                  color: iconColor ?? Colors.white.withOpacity(0.8),
                  size: 22),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
            validator: (v) {
              if (_selectedRideType == "Bike" && label.contains("Seats"))
                return null;
              if (v == null || v.isEmpty) {
                if (label.contains("From")) return "Location not detected";
                if (label.contains("go")) return "Please select destination";
                if (label.contains("Seats")) return "Enter number of seats";
              }
              if (label.contains("Seats") && v != null && v.isNotEmpty) {
                final seats = int.tryParse(v);
                if (seats == null || seats < 1) return "Enter valid number";
                if (seats > 6) return "Maximum 6 seats";
              }
              return null;
            },
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(helperText,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRideType,
        dropdownColor: const Color(0xFF2A5298),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: "Ride Type",
          labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.8), fontSize: 15),
          prefixIcon: Icon(Icons.directions_car,
              color: Colors.white.withOpacity(0.8), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 18),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        items: ["Car", "Bike"]
            .map((type) =>
            DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _selectedRideType = v;
            if (v == "Bike") {
              _seatsController.text = "1";
            } else if (v == "Car") {
              if (_seatsController.text.isEmpty ||
                  _seatsController.text == "1") {
                _seatsController.text = "4";
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildSwitchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: SwitchListTile(
        title: const Text("Allow Multiple Passengers",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text("Let multiple people book this ride",
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 13)),
        value: _allowMultiple,
        onChanged: (v) => setState(() => _allowMultiple = v),
        secondary: Icon(Icons.group, color: Colors.white.withOpacity(0.8)),
        activeColor: Colors.white,
        activeTrackColor: Colors.green.withOpacity(0.7),
      ),
    );
  }

  Widget _buildDateTimeButton(String dateTimeText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedDateTime == null
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: _pickDateTime,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  color: Colors.white.withOpacity(0.8), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  dateTimeText,
                  style: TextStyle(
                    color: _selectedDateTime == null
                        ? Colors.white.withOpacity(0.6)
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: _selectedDateTime == null
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _fromCoords!,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ghartak.app',
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _fromCoords!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: Colors.green, size: 40),
                ),
                if (_toCoords != null)
                  Marker(
                    point: _toCoords!,
                    width: 40,
                    height: 40,
                    child:
                    const Icon(Icons.flag, color: Colors.red, size: 40),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _postRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3C72),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
        ),
        icon: _isLoading
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF1E3C72))))
            : const Icon(Icons.upload),
        label: Text(
          _isLoading ? "Posting..." : "Post Ride",
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}