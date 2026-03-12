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

  static const Color kNavy = Color(0xFF1A2340);
  static const Color kYellow = Color(0xFFFFCC00);
  static const Color kBackground = Color(0xFFEEF0F5);

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
    final snapshot = await FirebaseFirestore.instance.collection('rides').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      final ts = data['timestamp'] as Timestamp?;
      final remaining = (data['remainingSeats'] ?? data['seats'] ?? 0) as int;

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

    return Container(
      color: kBackground,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1A2340)),
                  hintText: 'Search destination or poster',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
              ),
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
                  return const Center(
                    child: CircularProgressIndicator(color: kYellow),
                  );
                }

                final rides = snapshot.data!.docs.where((rideSnap) {
                  final ride = rideSnap.data() as Map<String, dynamic>;
                  final status = ride['status'];

                  if (status == 'cancelled' ||
                      status == 'expired' ||
                      status == 'completed') return false;

                  final acceptedByList = List.from(ride['acceptedByList'] ?? []);
                  if (acceptedByList.contains(currentUserId)) return false;

                  if (_searchQ == null || _searchQ!.isEmpty) return true;

                  final to = (ride['to'] ?? '').toString().toLowerCase();
                  final poster = (ride['postedByName'] ?? '').toString().toLowerCase();
                  return to.contains(_searchQ!) || poster.contains(_searchQ!);
                }).toList();

                if (rides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
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
                          child: const Icon(Icons.directions_car_outlined,
                              size: 48, color: kNavy),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No rides available",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Check back soon!",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideSnap = rides[index];
                    final rideData = rideSnap.data() as Map<String, dynamic>;

                    final from = rideData['from'] ?? "N/A";
                    final to = rideData['to'] ?? "N/A";
                    final remainingSeats =
                    (rideData['remainingSeats'] ?? rideData['seats'] ?? 0).toString();
                    final riderName =
                    (rideData['postedByName']?.toString().trim().isNotEmpty ?? false)
                        ? rideData['postedByName']
                        : "Unknown";
                    final cost = rideData['estimatedCost'] ?? 'N/A';
                    final ts = rideData['timestamp'] as Timestamp?;
                    final timeLeft = ts != null
                        ? _formatDuration(
                        (ts.toDate().add(const Duration(hours: 12)))
                            .difference(DateTime.now()))
                        : 'N/A';

                    final isExpiring = ts != null &&
                        (ts.toDate().add(const Duration(hours: 12)))
                            .difference(DateTime.now())
                            .inHours <
                            2;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          // Yellow top accent bar
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              color: kYellow,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Route
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFF4CAF50), width: 2),
                                          ),
                                        ),
                                        Container(
                                            width: 2, height: 22, color: Colors.grey.shade300),
                                        const Icon(Icons.location_on,
                                            color: Colors.redAccent, size: 14),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            from,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: kNavy),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            to,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: kNavy),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),
                                Container(
                                  height: 1,
                                  color: Colors.grey.shade100,
                                ),
                                const SizedBox(height: 12),

                                // Info chips row
                                Row(
                                  children: [
                                    _InfoChip(
                                      icon: Icons.event_seat_outlined,
                                      label: "$remainingSeats seats",
                                      color: kNavy,
                                    ),
                                    const SizedBox(width: 8),
                                    _InfoChip(
                                      icon: Icons.currency_rupee,
                                      label: "₹$cost",
                                      color: const Color(0xFF2E7D32),
                                      bgColor: const Color(0xFFE8F5E9),
                                    ),
                                    const Spacer(),
                                    _InfoChip(
                                      icon: Icons.timer_outlined,
                                      label: timeLeft,
                                      color: isExpiring
                                          ? const Color(0xFFB71C1C)
                                          : Colors.grey.shade600,
                                      bgColor: isExpiring
                                          ? const Color(0xFFFFEBEE)
                                          : Colors.grey.shade100,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Posted by
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: kYellow.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person,
                                          size: 14, color: kNavy),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        riderName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Info button
                                    GestureDetector(
                                      onTap: () => _showRideDetails(rideData),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: kNavy.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.info_outline,
                                                size: 16, color: kNavy),
                                            SizedBox(width: 4),
                                            Text("Details",
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: kNavy,
                                                    fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTrailing(context, rideSnap.id, rideData),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
              color: Color(0xFFEEF0F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_car,
                            color: Color(0xFF1A2340), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Ride Details',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2340))),
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
                      _DetailCard(
                        child: Column(
                          children: [
                            Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF4CAF50), width: 2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(clean(rideData['from']),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A2340))),
                              ),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 3),
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
                                  color: Colors.redAccent, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(clean(rideData['to']),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A2340))),
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
                                size: 17, color: Color(0xFF1A2340)),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEE, MMM dd · hh:mm a').format(dateTime),
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
                            value: '${rideData['remainingSeats'] ?? rideData['seats'] ?? 0}',
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
                            value: (rideData['allowMultiple'] == true) ? 'Yes' : 'No',
                          ),
                          _MiniTile(
                            icon: Icons.person_outline,
                            label: 'Posted By',
                            value: rideData['postedByName'] ?? 'Unknown',
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
      BuildContext context, String rideId, Map<String, dynamic> rideData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final currentUserName =
        currentUser?.displayName ?? currentUser?.email?.split('@').first ?? "User";
    final remaining =
    ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num).toInt();

    if (rideData['riderId'] == currentUserId) {
      return GestureDetector(
        onTap: () => _confirmCancel(context, rideId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
              SizedBox(width: 4),
              Text("Cancel",
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    } else if (remaining <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "Full",
          style: TextStyle(
              fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () async {
          final docRef =
          FirebaseFirestore.instance.collection('rides').doc(rideId);
          try {
            await FirebaseFirestore.instance.runTransaction((txn) async {
              final snapshot = await txn.get(docRef);
              if (!snapshot.exists) throw Exception("Ride no longer exists");

              final data = snapshot.data() as Map<String, dynamic>;
              int remainingSeatsNow =
              ((data['remainingSeats'] ?? data['seats'] ?? 1) as num).toInt();
              final allowMultiple = data['allowMultiple'] ?? false;

              if (remainingSeatsNow <= 0) throw Exception("No seats left");
              remainingSeatsNow--;

              final updates = <String, dynamic>{
                'remainingSeats': remainingSeatsNow,
                'acceptedAt': FieldValue.serverTimestamp(),
              };

              if (remainingSeatsNow <= 0) updates['status'] = 'accepted';

              if (!allowMultiple) {
                updates['acceptedBy'] = currentUserId;
                updates['acceptedByName'] = currentUserName;
              } else {
                final acceptedByList = List.from(data['acceptedByList'] ?? []);
                if (!acceptedByList.contains(currentUserId)) {
                  acceptedByList.add(currentUserId);
                }
                updates['acceptedByList'] = acceptedByList;
              }

              txn.update(docRef, updates);
            });

            final code = (1000 + Random.secure().nextInt(9000)).toString();
            await docRef.update({'rideCode': code});

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white),
                      SizedBox(width: 10),
                      Text("Ride accepted successfully!"),
                    ],
                  ),
                  backgroundColor: const Color(0xFF43A047),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC00),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF1A2340)),
              SizedBox(width: 4),
              Text("Accept",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A2340),
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
  }

  void _confirmCancel(BuildContext context, String rideId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Ride",
            style: TextStyle(
                color: Color(0xFF1A2340), fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to cancel this ride?",
            style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelRide(context, rideId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Cancel Ride"),
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.white),
                SizedBox(width: 10),
                Text("Ride cancelled successfully"),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
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

// ── Reusable chip widget ──────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFF1A2340).withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
  const _MiniTile({required this.icon, required this.label, required this.value});

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
          Icon(icon, size: 15, color: const Color(0xFF1A2340)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2340)),
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