import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class EnhancedMapPicker extends StatefulWidget {
  const EnhancedMapPicker({super.key});

  @override
  State<EnhancedMapPicker> createState() => _EnhancedMapPickerState();
}

class _EnhancedMapPickerState extends State<EnhancedMapPicker> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String _selectedAddress = "Tap on map to select destination";
  bool _isLoadingAddress = false;

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() => _isLoadingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address.isNotEmpty
              ? address
              : "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      debugPrint("Address fetch error: $e");
      setState(() {
        _selectedAddress = "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}";
      });
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  void _handleTap(TapPosition tapPos, LatLng latLng) async {
    setState(() {
      _selectedLocation = latLng;
    });

    // Move map to selected location
    _mapController.move(latLng, 15);

    // Fetch address
    await _getAddressFromCoordinates(latLng);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'address': _selectedAddress,
        'latLng': _selectedLocation,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please tap on map to select a destination"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Destination"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _confirmSelection,
            tooltip: "Confirm destination",
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(21.1702, 72.8311), // Surat, Gujarat
              initialZoom: 12,
              onTap: _handleTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ghartak.app',
              ),
              MarkerLayer(
                markers: [
                  if (_selectedLocation != null)
                    Marker(
                      point: _selectedLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 50,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Instruction card at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.blue.shade700,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedLocation == null
                            ? "Tap anywhere on the map to select destination"
                            : "Destination selected! Tap ✓ to confirm",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Address card at bottom
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Selected Destination",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _isLoadingAddress
                          ? const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text("Getting address..."),
                        ],
                      )
                          : Text(
                        _selectedAddress,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading overlay
          if (_isLoadingAddress && _selectedLocation == null)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}