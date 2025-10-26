// find_ride_widget.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';

class FindRideWidget extends StatefulWidget {
  final String userId;
  const FindRideWidget({super.key, required this.userId});

  @override
  State<FindRideWidget> createState() => _FindRideWidgetState();
}

class _FindRideWidgetState extends State<FindRideWidget> {
  String? _searchQ;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Periodically refresh the list to update countdowns
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "Expired";
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return "${hours}h ${minutes}m left";
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search destination or poster',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
          ),
        ),

        // Ride list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("rides")
                .orderBy("timestamp", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rides = snapshot.data!.docs.where((rideSnap) {
                final ride = rideSnap.data() as Map<String, dynamic>;

                // Skip cancelled or expired rides
                if (ride['status'] == 'cancelled' || ride['status'] == 'expired') return false;

                // Automatically expire rides older than 12 hours
                final ts = ride['timestamp'] as Timestamp?;
                if (ts != null) {
                  final age = DateTime.now().difference(ts.toDate());
                  if (age.inHours >= 12) {
                    FirebaseFirestore.instance
                        .collection('rides')
                        .doc(rideSnap.id)
                        .update({'status': 'expired'});
                    return false;
                  }
                }

                // Skip rides already accepted by current user
                final acceptedByList = List.from(ride['acceptedByList'] ?? []);
                if (acceptedByList.contains(currentUserId)) return false;

                // Search filter
                if (_searchQ == null || _searchQ!.isEmpty) return true;
                final to = (ride['to'] ?? '').toString().toLowerCase();
                final poster = (ride['postedByName'] ?? '').toString().toLowerCase();
                return to.contains(_searchQ!) || poster.contains(_searchQ!);
              }).toList();

              if (rides.isEmpty) {
                return const Center(child: Text("No rides available 🚗"));
              }

              return ListView.builder(
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  final rideSnap = rides[index];
                  final rideData = rideSnap.data() as Map<String, dynamic>;
                  final status = rideData['status'] ?? 'pending';
                  final from = rideData['from'] ?? "N/A";
                  final to = rideData['to'] ?? "N/A";
                  final remainingSeats =
                  (rideData['remainingSeats'] ?? rideData['seats'] ?? 0).toString();
                  final riderName = (rideData['postedByName']?.toString().trim().isNotEmpty ?? false)
                      ? rideData['postedByName']
                      : "Unknown";
                  final cost = rideData['estimatedCost'] ?? 'N/A';

                  // Time left until 12h expiry
                  final ts = rideData['timestamp'] as Timestamp?;
                  final timeLeft = ts != null
                      ? _formatDuration(
                      (ts.toDate().add(const Duration(hours: 12))).difference(DateTime.now())
                  )
                      : 'N/A';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
                        title: Text("$from ➝ $to", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text("Seats: $remainingSeats"),
                            const SizedBox(height: 4),
                            Text("Posted by: $riderName"),
                            const SizedBox(height: 4),
                            Text("💰 Cost: ₹$cost"),
                            const SizedBox(height: 4),
                            Text("⏱ $timeLeft", style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline, color: Colors.blue),
                              onPressed: () => _showRideDetails(rideData),
                            ),
                            _buildTrailing(context, rideSnap.id, rideData, status, riderName),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRideDetails(Map<String, dynamic> rideData) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🚗 Ride Details", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text("From: ${rideData['from']}"),
            Text("To: ${rideData['to']}"),
            Text(
                "Date & Time: ${rideData['dateTime'] != null ? (rideData['dateTime'] as Timestamp).toDate().toString() : 'N/A'}"),
            Text("Seats Available: ${rideData['remainingSeats'] ?? rideData['seats']}"),
            Text("Ride Type: ${rideData['rideType']}"),
            Text("Allow Multiple: ${rideData['allowMultiple'] ? 'Yes' : 'No'}"),
            Text("Distance: ${rideData['distance_km']?.toStringAsFixed(2) ?? 'N/A'} km"),
            Text("Duration: ${rideData['duration_min']?.toStringAsFixed(1) ?? 'N/A'} min"),
            const SizedBox(height: 8),
            Text("Posted By: ${rideData['postedByName'] ?? 'Unknown'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, String rideId,
      Map<String, dynamic> rideData, String status, String riderName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final currentUserName =
        currentUser?.displayName ?? currentUser?.email?.split('@').first ?? "User";

    final remaining = ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num).toInt();
    if (rideData['riderId'] == currentUserId) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () => _confirmCancel(context, rideId),
        child: const Text("Cancel Ride"),
      );
    } else if (remaining <= 0) {
      return const Text("No seats left", style: TextStyle(color: Colors.grey));
    } else {
      return ElevatedButton(
        onPressed: () async {
          final docRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
          try {
            await FirebaseFirestore.instance.runTransaction((txn) async {
              final snapshot = await txn.get(docRef);
              if (!snapshot.exists) throw Exception("Ride no longer exists");
              final data = snapshot.data() as Map<String, dynamic>;
              int remainingSeatsNow = ((data['remainingSeats'] ?? data['seats'] ?? 1) as num).toInt();
              final allowMultiple = data['allowMultiple'] ?? false;

              if (remainingSeatsNow <= 0) throw Exception("No seats left");

              remainingSeatsNow -= 1;
              final updates = <String, dynamic>{
                'remainingSeats': remainingSeatsNow,
                'acceptedAt': FieldValue.serverTimestamp(),
              };

              if (!allowMultiple || remainingSeatsNow == 0) {
                updates['status'] = 'accepted';
                updates['acceptedBy'] = currentUserId;
                updates['acceptedByName'] = currentUserName;
              } else {
                final acceptedByList = List.from(data['acceptedByList'] ?? []);
                if (!acceptedByList.contains(currentUserId)) acceptedByList.add(currentUserId);
                updates['acceptedByList'] = acceptedByList;
              }

              txn.update(docRef, updates);
            });

            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("Ride accepted successfully ✅")));
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => ChatPage(rideId: rideId)));
          } catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Error accepting ride: $e")));
          }
        },
        child: const Text("Accept & Chat"),
      );
    }
  }

  void _confirmCancel(BuildContext context, String rideId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride"),
        content: const Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("No")),
          TextButton(
            onPressed: () {
              _cancelRide(context, rideId);
              Navigator.of(ctx).pop();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide(BuildContext context, String rideId) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({'status': 'cancelled'});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Ride cancelled successfully ❌")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to cancel ride: $e")));
    }
  }
}
