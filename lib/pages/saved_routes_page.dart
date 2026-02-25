import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'post_ride.dart';
import 'enhanced_map_picker.dart';

class SavedRoutesPage extends StatelessWidget {
  final String userId;
  const SavedRoutesPage({Key? key, required this.userId}) : super(key: key);

  // ── Firestore ref helper ──────────────────────────────────────────────────
  CollectionReference _routesRef() => FirebaseFirestore.instance
      .collection("users")
      .doc(userId)
      .collection("saved_routes");

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteRoute(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E3C72).withOpacity(0.97),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Route",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Remove this route from your saved list?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _routesRef().doc(docId).delete();
    }
  }

  // ── Use Route ─────────────────────────────────────────────────────────────
  Future<void> _useRoute(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    await _routesRef().doc(docId).update({
      'usageCount': FieldValue.increment(1),
      'lastUsed': Timestamp.now(),
    });

    final doc = await _routesRef().doc(docId).get();
    final route = SavedRoute.fromFirestore(doc);

    if (!context.mounted) return;

    if (!route.hasCoords) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.info_outline, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
              child: Text("This route has no map data. Select locations manually.",
                  style: TextStyle(fontSize: 14))),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));

      Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRidePage()));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostRidePage(prefilledRoute: route)),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    final dt = (ts as Timestamp).toDate();
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  IconData _modeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case "car":   return Icons.directions_car_rounded;
      case "bus":   return Icons.directions_bus_rounded;
      case "bike":  return Icons.two_wheeler_rounded;
      case "walk":  return Icons.directions_walk_rounded;
      default:      return Icons.route_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF7E22CE)],
              ),
            ),
          ),

          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.08), Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.bookmark_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 10),
                      const Text(
                        "Saved Routes",
                        style: TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    "Tap 'Use Route' to open PostRide with it pre-filled",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13, letterSpacing: 0.3),
                  ),
                ),

                const SizedBox(height: 16),

                // Route List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _routesRef()
                        .orderBy("usageCount", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildRouteCard(context, doc.id, data, index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRouteSheet(context),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3C72),
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add Route", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Route Card ────────────────────────────────────────────────────────────
  Widget _buildRouteCard(BuildContext context, String docId,
      Map<String, dynamic> data, int index) {
    final usageCount = data["usageCount"] ?? 0;
    final isFavourite = data["isFavourite"] ?? false;
    final hasCoords = data['from_lat'] != null && data['to_lat'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFavourite
              ? Colors.amberAccent.withOpacity(0.6)
              : Colors.white.withOpacity(0.15),
          width: isFavourite ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_modeIcon(data["mode"]), color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data["nickname"] ?? "Route ${index + 1}",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (!hasCoords)
                        Text("No map data · text only",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await _routesRef().doc(docId).update({"isFavourite": !isFavourite});
                  },
                  child: Icon(
                    isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavourite ? Colors.amberAccent : Colors.white54,
                    size: 26,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _buildRouteStopRow(
              icon: Icons.radio_button_checked,
              iconColor: const Color(0xFF34D399),
              label: "From",
              value: data["fromAddress"] ?? data["from"] ?? "—",
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(width: 2, height: 18, color: Colors.white24),
            ),
            _buildRouteStopRow(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFF87171),
              label: "To",
              value: data["toAddress"] ?? data["to"] ?? "—",
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                if (data["mode"] != null)
                  _buildChip(Icons.directions_rounded, data["mode"],
                      const Color(0xFF818CF8)),
                if (data["time"] != null)
                  _buildChip(Icons.schedule_rounded, data["time"],
                      const Color(0xFF38BDF8)),
                _buildChip(Icons.replay_rounded, "Used $usageCount×",
                    const Color(0xFFA78BFA)),
                if (data["lastUsed"] != null)
                  _buildChip(Icons.history_rounded,
                      _formatTimestamp(data["lastUsed"]),
                      const Color(0xFF6EE7B7)),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _useRoute(context, docId, data),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text("Use Route",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3C72),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: () => _deleteRoute(context, docId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStopRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10, letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.bookmark_border_rounded,
                color: Colors.white54, size: 56),
          ),
          const SizedBox(height: 24),
          const Text("No Saved Routes Yet",
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            "Save routes from PostRide, or tap\n'+ Add Route' to add manually.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── FAB: Add Route — now with real map picker ─────────────────────────────
  void _showAddRouteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRouteSheet(routesRef: _routesRef()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful bottom sheet — handles map picking + location detect internally
// ─────────────────────────────────────────────────────────────────────────────
class _AddRouteSheet extends StatefulWidget {
  final CollectionReference routesRef;
  const _AddRouteSheet({required this.routesRef});

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  final nicknameCtrl = TextEditingController();
  final timeCtrl = TextEditingController();
  String selectedMode = "Car";

  // From
  String? fromAddress;
  LatLng? fromCoords;
  bool detectingFrom = false;

  // To
  String? toAddress;
  LatLng? toCoords;

  bool saving = false;

  @override
  void dispose() {
    nicknameCtrl.dispose();
    timeCtrl.dispose();
    super.dispose();
  }

  // ── Detect current location for "From" ───────────────────────────────────
  Future<void> _detectCurrentLocation() async {
    setState(() => detectingFrom = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack("Location services are disabled.", isError: true);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack("Location permission denied.", isError: true);
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack("Location permission permanently denied.", isError: true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          fromAddress = address.isNotEmpty ? address : "Current Location";
          fromCoords = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      _snack("Failed to detect location.", isError: true);
    } finally {
      setState(() => detectingFrom = false);
    }
  }

  // ── Pick "From" on map ────────────────────────────────────────────────────
  Future<void> _pickFrom() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        fromAddress = result['address'] as String?;
        fromCoords = result['latLng'] as LatLng?;
      });
    }
  }

  // ── Pick "To" on map ──────────────────────────────────────────────────────
  Future<void> _pickTo() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        toAddress = result['address'] as String?;
        toCoords = result['latLng'] as LatLng?;
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (fromAddress == null || toAddress == null) {
      _snack("Please select both From and To locations.", isError: true);
      return;
    }

    setState(() => saving = true);
    try {
      await widget.routesRef.add({
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'from': fromAddress,
        'to': toAddress,
        if (fromCoords != null) 'from_lat': fromCoords!.latitude,
        if (fromCoords != null) 'from_lng': fromCoords!.longitude,
        if (toCoords != null) 'to_lat': toCoords!.latitude,
        if (toCoords != null) 'to_lng': toCoords!.longitude,
        'nickname': nicknameCtrl.text.trim().isEmpty
            ? "$fromAddress → $toAddress"
            : nicknameCtrl.text.trim(),
        'time': timeCtrl.text.trim(),
        'mode': selectedMode,
        'usageCount': 0,
        'isFavourite': false,
        'createdAt': Timestamp.now(),
        'savedAt': Timestamp.now(),
        'lastUsed': null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Text("Route saved!", style: TextStyle(fontSize: 15)),
          ]),
          backgroundColor: const Color(0xFF43A047),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      _snack("Failed to save: $e", isError: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              const Text("Save a Route",
                  style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                "Select locations on the map for full route pre-fill support.",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ── FROM ──────────────────────────────────────────────────────
              Text("From", style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 13,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              const SizedBox(height: 8),
              _locationTile(
                address: fromAddress,
                icon: Icons.radio_button_checked,
                iconColor: const Color(0xFF34D399),
                placeholder: "Select starting point",
                onMapTap: _pickFrom,
                onDetectTap: _detectCurrentLocation,
                detecting: detectingFrom,
              ),
              const SizedBox(height: 16),

              // ── TO ────────────────────────────────────────────────────────
              Text("To", style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 13,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              const SizedBox(height: 8),
              _locationTile(
                address: toAddress,
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFFF87171),
                placeholder: "Select destination",
                onMapTap: _pickTo,
              ),
              const SizedBox(height: 16),

              // ── Nickname ──────────────────────────────────────────────────
              _sheetField(nicknameCtrl, "Nickname (e.g. Home → College)",
                  Icons.label_outline, Colors.white70),
              const SizedBox(height: 12),

              // ── Time ──────────────────────────────────────────────────────
              _sheetField(timeCtrl, "Preferred Time (e.g. 8:00 AM)",
                  Icons.schedule_rounded, const Color(0xFF38BDF8)),
              const SizedBox(height: 16),

              // ── Mode ──────────────────────────────────────────────────────
              const Text("Transport Mode",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ["Car", "Bike"].map((mode) {
                  final selected = selectedMode == mode;
                  return GestureDetector(
                    onTap: () => setState(() => selectedMode = mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(mode,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF1E3C72)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Save Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3C72),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: Colors.white.withOpacity(0.5),
                  ),
                  child: saving
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3C72))))
                      : const Text("Save Route",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Location tile with map + detect buttons ───────────────────────────────
  Widget _locationTile({
    required String? address,
    required IconData icon,
    required Color iconColor,
    required String placeholder,
    required VoidCallback onMapTap,
    VoidCallback? onDetectTap,
    bool detecting = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: address != null
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              address ?? placeholder,
              style: TextStyle(
                color: address != null
                    ? Colors.white
                    : Colors.white.withOpacity(0.45),
                fontSize: 14,
                fontWeight: address != null ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Detect location button (only for "From")
          if (onDetectTap != null)
            GestureDetector(
              onTap: detecting ? null : onDetectTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: detecting
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.my_location,
                    color: Colors.white, size: 18),
              ),
            ),
          if (onDetectTap != null) const SizedBox(width: 8),
          // Map picker button
          GestureDetector(
            onTap: onMapTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint,
      IconData icon, Color iconColor) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white60, width: 1.5),
        ),
      ),
    );
  }
}