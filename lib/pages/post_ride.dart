import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'map_picker_page.dart';

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
  bool _isLoading = false;

  String? _selectedRideType = "Car";
  bool _allowMultiple = true;

  double? _distanceKm;
  double? _durationMin;

  // Replace with your OpenRouteService API key
  final String orsApiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjAzOThjYTYwYTU0ZDRkNmRiYWE0OWM4MjNiMjk1YzA5IiwiaCI6Im11cm11cjY0In0=";

  // ✅ Get current location for "From"
  Future<void> _fillCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Location services disabled")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Permission denied")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Location permission permanently denied")),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address =
            "${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}";
        setState(() {
          _fromController.text = address;
          _fromCoords = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  // ✅ Pick destination via map (returns address + latLng)
  Future<void> _pickDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final address = result['address'] as String?;
      final coords = result['latLng'] as LatLng?;

      if (address != null && coords != null) {
        setState(() {
          _toController.text = address;
          _toCoords = coords;
        });

        // After selecting destination, auto-calc route info
        if (_fromCoords != null && _toCoords != null) {
          await _calculateRouteInfo();
        }
      }
    }
  }

  // ✅ Use OpenRouteService to calculate distance and duration
  Future<void> _calculateRouteInfo() async {
    try {
      final url = Uri.parse(
          "https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${_fromCoords!.longitude},${_fromCoords!.latitude}&end=${_toCoords!.longitude},${_toCoords!.latitude}");

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final props = data['features'][0]['properties']['segments'][0];

        setState(() {
          _distanceKm = props['distance'] / 1000; // meters to km
          _durationMin = props['duration'] / 60; // seconds to minutes
        });
      } else {
        throw Exception("Failed to fetch route info");
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  // ✅ Pick date & time
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ✅ Post ride
  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDateTime == null ||
        _fromCoords == null ||
        _toCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please complete all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String userName = "Unknown";
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data()?['name'] != null) {
        userName = userDoc['name'];
      } else if (user.displayName?.isNotEmpty ?? false) {
        userName = user.displayName!;
      } else if (user.email?.contains('@') ?? false) {
        userName = user.email!.split('@').first;
      }

      // Calculate estimated cost (₹3/km per seat)
      final estCost =
          (_distanceKm != null ? _distanceKm! * 3 : 20) * (int.tryParse(_seatsController.text) ?? 1);

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'from_lat': _fromCoords!.latitude,
        'from_lng': _fromCoords!.longitude,
        'to_lat': _toCoords!.latitude,
        'to_lng': _toCoords!.longitude,
        'seats': int.tryParse(_seatsController.text.trim()) ?? 1,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Ride posted successfully by $userName")),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedDateTime = null;
        _toCoords = null;
        _fromCoords = null;
        _distanceKm = null;
        _durationMin = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Error posting ride: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeText = _selectedDateTime == null
        ? "Pick Date & Time"
        : DateFormat('yyyy-MM-dd hh:mm a').format(_selectedDateTime!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Ride"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // From field
              TextFormField(
                controller: _fromController,
                decoration: InputDecoration(
                  labelText: "From",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _fillCurrentLocation,
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Enter source" : null,
              ),

              // To field
              TextFormField(
                controller: _toController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "To (tap map icon)",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _pickDestination,
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Select destination" : null,
              ),

              // Ride type dropdown (only Car & Bike)
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedRideType,
                decoration: const InputDecoration(labelText: "Ride Type"),
                items: ["Car", "Bike"]
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRideType = v),
              ),

              // Allow multiple passengers
              SwitchListTile(
                title: const Text("Allow multiple passengers"),
                value: _allowMultiple,
                onChanged: (v) => setState(() => _allowMultiple = v),
              ),

              // Seats
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(labelText: "Available Seats"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter number of seats" : null,
              ),

              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(dateTimeText),
                onPressed: _pickDateTime,
              ),

              // Show distance & duration if available
              if (_distanceKm != null && _durationMin != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "📏 Distance: ${_distanceKm!.toStringAsFixed(2)} km | ⏱️ ${_durationMin!.toStringAsFixed(1)} min",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),

              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _isLoading ? null : _postRide,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Post Ride"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
