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

  static const Color kNavy = Color(0xFF1A2340);
  static const Color kYellow = Color(0xFFFFCC00);
  static const Color kBackground = Color(0xFFEEF0F5);

  CollectionReference _routesRef() => FirebaseFirestore.instance
      .collection("users")
      .doc(userId)
      .collection("saved_routes");

  Future<void> _deleteRoute(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Remove Route",
                style: TextStyle(
                    color: kNavy, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("Remove this route from your saved list?",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel",
                style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
              child: Text("No map data. Select locations manually.",
                  style: TextStyle(fontSize: 14))),
        ]),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PostRidePage()));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PostRidePage(prefilledRoute: route)),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    final dt = (ts as Timestamp).toDate();
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  IconData _modeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case "car":
        return Icons.directions_car_rounded;
      case "bus":
        return Icons.directions_bus_rounded;
      case "bike":
        return Icons.two_wheeler_rounded;
      case "walk":
        return Icons.directions_walk_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _routesRef()
                  .orderBy("usageCount", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kNavy));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRouteSheet(context),
        backgroundColor: kNavy,
        foregroundColor: kYellow,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add Route",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: kNavy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bookmark_rounded, color: kNavy, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            "Saved Routes",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, String docId,
      Map<String, dynamic> data, int index) {
    final usageCount = data["usageCount"] ?? 0;
    final isFavourite = data["isFavourite"] ?? false;
    final hasCoords = data['from_lat'] != null && data['to_lat'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isFavourite
            ? Border.all(color: kYellow, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isFavourite ? kYellow : kNavy,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_modeIcon(data["mode"]),
                          color: kNavy, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data["nickname"] ?? "Route ${index + 1}",
                            style: const TextStyle(
                                color: kNavy,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          if (!hasCoords)
                            Text("Text only · no map data",
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await _routesRef()
                            .doc(docId)
                            .update({"isFavourite": !isFavourite});
                      },
                      child: Icon(
                        isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: isFavourite ? kYellow : Colors.grey.shade400,
                        size: 26,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Route stops
                _buildRouteStopRow(
                  icon: Icons.radio_button_checked,
                  iconColor: const Color(0xFF4CAF50),
                  label: "From",
                  value: data["fromAddress"] ?? data["from"] ?? "—",
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                      width: 2, height: 16, color: Colors.grey.shade200),
                ),
                _buildRouteStopRow(
                  icon: Icons.location_on_rounded,
                  iconColor: Colors.redAccent,
                  label: "To",
                  value: data["toAddress"] ?? data["to"] ?? "—",
                ),

                const SizedBox(height: 12),
                Container(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),

                // Meta chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (data["mode"] != null)
                      _buildChip(Icons.directions_rounded, data["mode"],
                          kNavy),
                    if (data["time"] != null)
                      _buildChip(
                          Icons.schedule_rounded, data["time"], kNavy),
                    _buildChip(Icons.replay_rounded, "Used $usageCount×",
                        Colors.grey.shade600),
                    if (data["lastUsed"] != null)
                      _buildChip(Icons.history_rounded,
                          _formatTimestamp(data["lastUsed"]),
                          Colors.grey.shade600),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _useRoute(context, docId, data),
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: kYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded,
                                  size: 16, color: kNavy),
                              SizedBox(width: 6),
                              Text("Use Route",
                                  style: TextStyle(
                                      color: kNavy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _deleteRoute(context, docId),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                      letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: kNavy,
                      fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.bookmark_border_rounded,
                color: kNavy, size: 48),
          ),
          const SizedBox(height: 20),
          const Text("No Saved Routes Yet",
              style: TextStyle(
                  color: kNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Save routes from PostRide, or tap\n'+ Add Route' to add manually.",
            textAlign: TextAlign.center,
            style:
            TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

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
// Add Route Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddRouteSheet extends StatefulWidget {
  final CollectionReference routesRef;
  const _AddRouteSheet({required this.routesRef});

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  static const Color kNavy = Color(0xFF1A2340);
  static const Color kYellow = Color(0xFFFFCC00);

  final nicknameCtrl = TextEditingController();
  final timeCtrl = TextEditingController();
  String selectedMode = "Car";

  String? fromAddress;
  LatLng? fromCoords;
  bool detectingFrom = false;

  String? toAddress;
  LatLng? toCoords;

  bool saving = false;

  @override
  void dispose() {
    nicknameCtrl.dispose();
    timeCtrl.dispose();
    super.dispose();
  }

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
          fromAddress =
          address.isNotEmpty ? address : "Current Location";
          fromCoords = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      _snack("Failed to detect location.", isError: true);
    } finally {
      setState(() => detectingFrom = false);
    }
  }

  Future<void> _pickFrom() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        fromAddress = result['address'] as String?;
        fromCoords = result['latLng'] as LatLng?;
      });
    }
  }

  Future<void> _pickTo() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        toAddress = result['address'] as String?;
        toCoords = result['latLng'] as LatLng?;
      });
    }
  }

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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor:
      isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kYellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bookmark_add_rounded,
                        color: kNavy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text("Save a Route",
                      style: TextStyle(
                          color: kNavy,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Select map locations for full route pre-fill support.",
                style:
                TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // FROM
              Text("From",
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              _locationTile(
                address: fromAddress,
                icon: Icons.radio_button_checked,
                iconColor: const Color(0xFF4CAF50),
                placeholder: "Select starting point",
                onMapTap: _pickFrom,
                onDetectTap: _detectCurrentLocation,
                detecting: detectingFrom,
              ),
              const SizedBox(height: 14),

              // TO
              Text("To",
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              _locationTile(
                address: toAddress,
                icon: Icons.location_on_rounded,
                iconColor: Colors.redAccent,
                placeholder: "Select destination",
                onMapTap: _pickTo,
              ),
              const SizedBox(height: 14),

              _sheetField(nicknameCtrl, "Nickname (e.g. Home → College)",
                  Icons.label_outline),
              const SizedBox(height: 10),
              _sheetField(timeCtrl, "Preferred Time (e.g. 8:00 AM)",
                  Icons.schedule_rounded),
              const SizedBox(height: 14),

              // Mode
              Text("Transport Mode",
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ["Car", "Bike"].map((mode) {
                  final selected = selectedMode == mode;
                  return GestureDetector(
                    onTap: () => setState(() => selectedMode = mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? kNavy : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(mode,
                          style: TextStyle(
                              color: selected ? Colors.white : kNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: kNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    disabledBackgroundColor: kYellow.withOpacity(0.4),
                  ),
                  child: saving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation(kNavy)))
                      : const Text("Save Route",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        color: address != null
            ? const Color(0xFFEEF0F5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: address != null
              ? const Color(0xFF1A2340).withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address ?? placeholder,
              style: TextStyle(
                color: address != null
                    ? const Color(0xFF1A2340)
                    : Colors.grey.shade400,
                fontSize: 13,
                fontWeight: address != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (onDetectTap != null)
            GestureDetector(
              onTap: detecting ? null : onDetectTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2340).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: detecting
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A2340)))
                    : const Icon(Icons.my_location,
                    color: Color(0xFF1A2340), size: 16),
              ),
            ),
          if (onDetectTap != null) const SizedBox(width: 6),
          GestureDetector(
            onTap: onMapTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2340).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined,
                  color: Color(0xFF1A2340), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Color(0xFF1A2340), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon:
        Icon(icon, color: Colors.grey.shade500, size: 18),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF1A2340), width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}