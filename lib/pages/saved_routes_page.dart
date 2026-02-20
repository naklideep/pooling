import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedRoutesPage extends StatelessWidget {
  final String userId;
  const SavedRoutesPage({Key? key, required this.userId}) : super(key: key);

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
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("saved_routes")
          .doc(docId)
          .delete();
    }
  }

  Future<void> _useRoute(BuildContext context, Map<String, dynamic> data) async {
    // Increment usageCount so most-used routes bubble up
    final routes = FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("saved_routes");

    final snap = await routes
        .where("from", isEqualTo: data["from"])
        .where("to", isEqualTo: data["to"])
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        "usageCount": FieldValue.increment(1),
        "lastUsed": Timestamp.now(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Route loaded: ${data["from"]} → ${data["to"]}",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    // TODO: Pass data["from"], data["to"], data["mode"], data["time"]
    // to your FindRide/PostRide widget via Navigator or a state manager
    Navigator.pop(context, data);
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
      body: Stack(
        children: [
          // Same gradient background as dashboard
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

          // Decorative circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.bookmark_rounded,
                          color: Colors.white, size: 26),
                      const SizedBox(width: 10),
                      const Text(
                        "Saved Routes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Subtitle ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Text(
                    "Your most used & favourite routes",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Route List ────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(userId)
                        .collection("saved_routes")
                        .orderBy("usageCount", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data =
                          doc.data() as Map<String, dynamic>;
                          return _buildRouteCard(
                              context, doc.id, data, index);
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

      // ── FAB to manually add a saved route ────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRouteSheet(context),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3C72),
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add Route",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Route Card ──────────────────────────────────────────────────────────────
  Widget _buildRouteCard(BuildContext context, String docId,
      Map<String, dynamic> data, int index) {
    final usageCount = data["usageCount"] ?? 0;
    final isFavourite = data["isFavourite"] ?? false;

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
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Mode icon + nickname + favourite star ──────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_modeIcon(data["mode"]),
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data["nickname"] ?? "Route ${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Favourite toggle
                GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(userId)
                        .collection("saved_routes")
                        .doc(docId)
                        .update({"isFavourite": !isFavourite});
                  },
                  child: Icon(
                    isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavourite
                        ? Colors.amberAccent
                        : Colors.white54,
                    size: 26,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── From → To ───────────────────────────────────────────
            _buildRouteStopRow(
              icon: Icons.radio_button_checked,
              iconColor: const Color(0xFF34D399),
              label: "From",
              value: data["from"] ?? "—",
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 18,
                color: Colors.white24,
              ),
            ),
            _buildRouteStopRow(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFF87171),
              label: "To",
              value: data["to"] ?? "—",
            ),

            const SizedBox(height: 14),

            // ── Meta: mode, time, usage ─────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (data["mode"] != null)
                  _buildChip(Icons.directions_rounded,
                      data["mode"], const Color(0xFF818CF8)),
                if (data["time"] != null)
                  _buildChip(Icons.schedule_rounded,
                      data["time"], const Color(0xFF38BDF8)),
                _buildChip(Icons.replay_rounded,
                    "Used $usageCount times", const Color(0xFFA78BFA)),
                if (data["lastUsed"] != null)
                  _buildChip(Icons.history_rounded,
                      _formatTimestamp(data["lastUsed"]),
                      const Color(0xFF6EE7B7)),
              ],
            ),

            const SizedBox(height: 14),

            // ── Action Buttons ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _useRoute(context, data),
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
                    border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3)),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 0.5)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
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
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────
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
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            "Tap '+ Add Route' to save your\nmost used routes for quick access.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet: Add Route Manually ────────────────────────────────────────
  void _showAddRouteSheet(BuildContext context) {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    String selectedMode = "Car";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          // ← CHANGED: padding wrap outside Container
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            // ← REMOVED bottom padding from here
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            // ← ADD THIS: wrap content in SingleChildScrollView
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Save a Route",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  _sheetField(fromCtrl, "From", Icons.radio_button_checked,
                      const Color(0xFF34D399)),
                  const SizedBox(height: 12),
                  _sheetField(toCtrl, "To", Icons.location_on_rounded,
                      const Color(0xFFF87171)),
                  const SizedBox(height: 12),
                  _sheetField(nicknameCtrl, "Nickname (e.g. Home → College)",
                      Icons.label_outline, Colors.white70),
                  const SizedBox(height: 12),
                  _sheetField(timeCtrl, "Preferred Time (e.g. 8:00 AM)",
                      Icons.schedule_rounded, const Color(0xFF38BDF8)),
                  const SizedBox(height: 16),

                  const Text("Transport Mode",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ["Car","Bike"].map((mode) {
                      final selected = selectedMode == mode;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedMode = mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (fromCtrl.text.trim().isEmpty ||
                            toCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("From and To fields are required.")),
                          );
                          return;
                        }
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(userId)
                            .collection("saved_routes")
                            .add({
                          "from": fromCtrl.text.trim(),
                          "to": toCtrl.text.trim(),
                          "nickname": nicknameCtrl.text.trim().isEmpty
                              ? "${fromCtrl.text.trim()} → ${toCtrl.text.trim()}"
                              : nicknameCtrl.text.trim(),
                          "time": timeCtrl.text.trim(),
                          "mode": selectedMode,
                          "usageCount": 0,
                          "isFavourite": false,
                          "createdAt": Timestamp.now(),
                          "lastUsed": null,
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3C72),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Save Route",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 8), // ← little breathing room at bottom
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon,
      Color iconColor) {
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
          borderSide:
          const BorderSide(color: Colors.white60, width: 1.5),
        ),
      ),
    );
  }
}
