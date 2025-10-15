import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
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
  LatLng? _toCoords;
  DateTime? _selectedDateTime;
  bool _isLoading = false;

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
        setState(() => _fromController.text = address);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  // ✅ Pick destination via map (updated to handle {address, latLng})
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Failed to get location details")),
        );
      }
    }
  }

  // ✅ Date & time picker
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

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'to_lat': _toCoords!.latitude,
        'to_lng': _toCoords!.longitude,
        'seats': int.tryParse(_seatsController.text.trim()) ?? 1,
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
              TextFormField(
                controller: _seatsController,
                decoration:
                const InputDecoration(labelText: "Available Seats"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter number of seats" : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(dateTimeText),
                onPressed: _pickDateTime,
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
