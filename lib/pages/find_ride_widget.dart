import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';
import 'ride_active_page.dart';

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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _autoUpdateRideStatus();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _autoUpdateRideStatus() async {
    final now = DateTime.now();
    final snapshot =
    await FirebaseFirestore.instance.collection('rides').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      final ts = data['timestamp'] as Timestamp?;
      final remaining =
      (data['remainingSeats'] ?? data['seats'] ?? 0) as int;

      if (ts != null &&
          now.difference(ts.toDate()).inHours >= 12 &&
          status != 'expired') {
        await doc.reference.update({'status': 'expired'});
      }

      if (remaining <= 0 && status == 'pending') {
        await doc.reference.update({'status': 'accepted'});
      }
    }
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search destination or poster',
              prefixIconColor: Colors.white,
              hintStyle: TextStyle(color: Colors.white),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) =>
                setState(() => _searchQ = v.trim().toLowerCase()),
          ),
        ),
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
                final status = ride['status'];

                if (status == 'cancelled' ||
                    status == 'expired' ||
                    status == 'completed') return false;

                final acceptedByList =
                List.from(ride['acceptedByList'] ?? []);
                if (acceptedByList.contains(currentUserId)) return false;

                if (_searchQ == null || _searchQ!.isEmpty) return true;

                final to = (ride['to'] ?? '').toString().toLowerCase();
                final poster =
                (ride['postedByName'] ?? '').toString().toLowerCase();
                return to.contains(_searchQ!) ||
                    poster.contains(_searchQ!);
              }).toList();

              if (rides.isEmpty) {
                return const Center(child: Text("No rides available 🚗"));
              }

              return ListView.builder(
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  final rideSnap = rides[index];
                  final rideData =
                  rideSnap.data() as Map<String, dynamic>;

                  final from = rideData['from'] ?? "N/A";
                  final to = rideData['to'] ?? "N/A";
                  final remainingSeats =
                  (rideData['remainingSeats'] ?? rideData['seats'] ?? 0)
                      .toString();
                  final riderName =
                  (rideData['postedByName']?.toString().trim().isNotEmpty ??
                      false)
                      ? rideData['postedByName']
                      : "Unknown";
                  final cost = rideData['estimatedCost'] ?? 'N/A';
                  final ts = rideData['timestamp'] as Timestamp?;
                  final timeLeft = ts != null
                      ? _formatDuration(
                      (ts.toDate().add(const Duration(hours: 12)))
                          .difference(DateTime.now()))
                      : 'N/A';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.trip_origin,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(from,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 9),
                            child: Container(
                                width: 2,
                                height: 16,
                                color: Colors.grey.shade300),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(to,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Seats: $remainingSeats"),
                              Text("💰 ₹$cost"),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Text("Posted by: $riderName",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),

                          const SizedBox(height: 4),

                          Text("⏱ $timeLeft",
                              style: const TextStyle(color: Colors.red)),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: Colors.blue),
                                onPressed: () =>
                                    _showRideDetails(rideData),
                              ),
                              _buildTrailing(
                                  context, rideSnap.id, rideData),
                            ],
                          ),
                        ],
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
    String clean(dynamic v) {
      if (v is Map && v.containsKey("address")) return v["address"];
      return v?.toString() ?? 'N/A';
    }

    final ts = rideData['dateTime'] as Timestamp?;
    final dateTime = ts?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FA),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_car,
                            color: Colors.indigo, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Ride Details',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Route card
                      _DetailCard(
                        child: Column(
                          children: [
                            Row(children: [
                              const Icon(Icons.trip_origin,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(clean(rideData['from']),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                    width: 2,
                                    height: 20,
                                    color: Colors.grey.shade300),
                              ),
                            ),
                            Row(children: [
                              const Icon(Icons.location_on,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(clean(rideData['to']),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (dateTime != null)
                        _DetailCard(
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 17, color: Colors.blueGrey),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEE, MMM dd · hh:mm a')
                                  .format(dateTime),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 12),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.4,
                        children: [
                          _MiniTile(
                            icon: Icons.event_seat_outlined,
                            label: 'Seats Available',
                            value:
                            '${rideData['remainingSeats'] ?? rideData['seats'] ?? 0}',
                          ),
                          _MiniTile(
                            icon: Icons.directions_car_outlined,
                            label: 'Ride Type',
                            value: rideData['rideType'] ?? 'N/A',
                          ),
                          _MiniTile(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value:
                            '${(rideData['distance_km'] ?? 0).toStringAsFixed(1)} km',
                          ),
                          _MiniTile(
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value:
                            '${(rideData['duration_min'] ?? 0).toStringAsFixed(0)} min',
                          ),
                          _MiniTile(
                            icon: Icons.people_outline,
                            label: 'Allow Multiple',
                            value: (rideData['allowMultiple'] == true)
                                ? 'Yes'
                                : 'No',
                          ),
                          _MiniTile(
                            icon: Icons.person_outline,
                            label: 'Posted By',
                            value:
                            rideData['postedByName'] ?? 'Unknown',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailing(
      BuildContext context,
      String rideId,
      Map<String, dynamic> rideData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final currentUserName = currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        "User";
    final remaining =
    ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num)
        .toInt();

    if (rideData['riderId'] == currentUserId) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () => _confirmCancel(context, rideId),
        child: const Text("Cancel Ride"),
      );
    } else if (remaining <= 0) {
      return const Text("No seats left",
          style: TextStyle(color: Colors.grey));
    } else {
      return ElevatedButton(
        onPressed: () async {
          final docRef = FirebaseFirestore.instance
              .collection('rides')
              .doc(rideId);
          try {
            await FirebaseFirestore.instance
                .runTransaction((txn) async {
              final snapshot = await txn.get(docRef);
              if (!snapshot.exists)
                throw Exception("Ride no longer exists");

              final data = snapshot.data() as Map<String, dynamic>;
              int remainingSeatsNow =
              ((data['remainingSeats'] ?? data['seats'] ?? 1) as num)
                  .toInt();
              final allowMultiple = data['allowMultiple'] ?? false;

              if (remainingSeatsNow <= 0)
                throw Exception("No seats left");
              remainingSeatsNow--;

              final updates = <String, dynamic>{
                'remainingSeats': remainingSeatsNow,
                'acceptedAt': FieldValue.serverTimestamp(),
              };

              if (remainingSeatsNow <= 0)
                updates['status'] = 'accepted';

              if (!allowMultiple) {
                updates['acceptedBy'] = currentUserId;
                updates['acceptedByName'] = currentUserName;
              } else {
                final acceptedByList =
                List.from(data['acceptedByList'] ?? []);
                if (!acceptedByList.contains(currentUserId)) {
                  acceptedByList.add(currentUserId);
                }
                updates['acceptedByList'] = acceptedByList;
              }

              txn.update(docRef, updates);
            });

            // ✅ Generate 4-digit code AFTER transaction succeeds
            final code =
            (1000 + Random.secure().nextInt(9000)).toString();
            await docRef.update({'rideCode': code});

            // ✅ Navigate to RideActivePage instead of ChatPage
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Ride accepted successfully ✅")),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideActivePage(
                    rideId: rideId,
                    userId: currentUserId,
                    isDriver: false,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error accepting ride: $e")),
              );
            }
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
        content:
        const Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("No")),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelRide(context, rideId);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide(BuildContext context, String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .update({'status': 'cancelled'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Ride cancelled successfully ❌")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel ride: $e")),
        );
      }
    }
  }
}

// ── Top-level reusable widgets ────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.blueGrey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}