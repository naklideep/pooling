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

class PostRidePage extends StatefulWidget {
  const PostRidePage({super.key});

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage> {
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
  String? _selectedRideType = "Car";
  bool _allowMultiple = true;

  double? _distanceKm;
  double? _durationMin;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _autoDetectCurrentLocation();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  /// 🛰️ Detect and center on current location automatically
  Future<void> _autoDetectCurrentLocation() async {
    setState(() => _loadingMap = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled. Please enable them.");
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
        _showError("Location permission permanently denied. Enable in settings.");
        setState(() => _loadingMap = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks =
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
          _fromController.text = address.isNotEmpty ? address : "Current Location";
          _fromCoords = LatLng(pos.latitude, pos.longitude);
          _loadingMap = false;
        });

        // Auto move the map
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
          }
        });

        _showSuccess("Location detected successfully!");
      }
    } catch (e) {
      debugPrint("⚠️ Auto detect location failed: $e");
      _showError("Failed to detect location: ${e.toString()}");
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
              .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble()))
              .toList();
        });

        // Fit map to route
        if (_routePoints.isNotEmpty && mounted) {
          final bounds = LatLngBounds.fromPoints(_routePoints);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50),
                ),
              );
            }
          });
        }
      } else {
        throw Exception("Route API returned status ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
      _showError("Failed to calculate route. Please try again.");
    } finally {
      setState(() => _calculatingRoute = false);
    }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EnhancedMapPicker()),
    );

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
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
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

    // Check if datetime is in the past
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

      // Reset form
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

      // Re-detect location for next ride
      _autoDetectCurrentLocation();

    } catch (e) {
      debugPrint("Error posting ride: $e");
      _showError("❌ Error posting ride: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeText = _selectedDateTime == null
        ? "Pick Date & Time"
        : DateFormat('MMM dd, yyyy • hh:mm a').format(_selectedDateTime!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Ride"),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Detect current location',
            onPressed: _loadingMap ? null : _autoDetectCurrentLocation,
          ),
        ],
      ),
      body: _loadingMap
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Detecting your location..."),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Info card
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Your current location is auto-detected. Just select your destination!",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // From location (current location - read only)
              TextFormField(
                controller: _fromController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "From (Your Current Location)",
                  prefixIcon: Icon(Icons.my_location, color: Colors.green),
                  border: OutlineInputBorder(),
                  helperText: "Tap refresh icon above to re-detect",
                ),
                validator: (v) =>
                v == null || v.isEmpty ? "Location not detected" : null,
              ),
              const SizedBox(height: 12),

              // To location
              TextFormField(
                controller: _toController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Where do you want to go?",
                  prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _pickDestination,
                    tooltip: "Pick destination on map",
                  ),
                  border: const OutlineInputBorder(),
                  helperText: "Tap map icon to select destination",
                ),
                validator: (v) =>
                v == null || v.isEmpty ? "Please select destination" : null,
              ),
              const SizedBox(height: 16),

              // Route info card
              if (_calculatingRoute)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("Calculating route..."),
                      ],
                    ),
                  ),
                )
              else if (_distanceKm != null && _durationMin != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoChip(
                          Icons.straighten,
                          "${_distanceKm!.toStringAsFixed(1)} km",
                          "Distance",
                        ),
                        _buildInfoChip(
                          Icons.schedule,
                          "${_durationMin!.toStringAsFixed(0)} min",
                          "Duration",
                        ),
                        _buildInfoChip(
                          Icons.currency_rupee,
                          "${((_distanceKm! * 3) * (int.tryParse(_seatsController.text) ?? 1)).toStringAsFixed(0)}",
                          "Est. Cost",
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Ride type dropdown
              DropdownButtonFormField<String>(
                value: _selectedRideType,
                decoration: const InputDecoration(
                  labelText: "Ride Type",
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                items: ["Car", "Bike"]
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRideType = v),
              ),
              const SizedBox(height: 12),

              // Available seats
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(
                  labelText: "Available Seats",
                  prefixIcon: Icon(Icons.event_seat),
                  border: OutlineInputBorder(),
                  hintText: "e.g., 4",
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter number of seats";
                  final seats = int.tryParse(v);
                  if (seats == null || seats < 1) return "Enter valid number";
                  if (seats > 10) return "Maximum 10 seats allowed";
                  return null;
                },
                onChanged: (_) {
                  // Recalculate cost when seats change
                  if (_distanceKm != null) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),

              // Allow multiple passengers switch
              Card(
                child: SwitchListTile(
                  title: const Text("Allow Multiple Passengers"),
                  subtitle: const Text("Let multiple people book this ride"),
                  value: _allowMultiple,
                  onChanged: (v) => setState(() => _allowMultiple = v),
                  secondary: const Icon(Icons.group),
                ),
              ),
              const SizedBox(height: 16),

              // Date time picker
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  dateTimeText,
                  style: TextStyle(
                    color: _selectedDateTime == null
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(
                    color: _selectedDateTime == null
                        ? Colors.grey
                        : Colors.blue,
                    width: 2,
                  ),
                ),
                onPressed: _pickDateTime,
              ),
              const SizedBox(height: 16),

              // Map preview
              if (_fromCoords != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 250,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _fromCoords!,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.ghartak.app',
                        ),
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 4.0,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _fromCoords!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                            if (_toCoords != null)
                              Marker(
                                point: _toCoords!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Post ride button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _postRide,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.upload),
                label: Text(
                  _isLoading ? "Posting..." : "Post Ride",
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}