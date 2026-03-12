import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'chat_page.dart';
import 'live_ride_tracking_page.dart';
import 'ride_active_page.dart';

class YourRidesPage extends StatefulWidget {
  final String userId;
  const YourRidesPage({required this.userId, Key? key}) : super(key: key);

  @override
  State<YourRidesPage> createState() => _YourRidesPageState();
}

class _YourRidesPageState extends State<YourRidesPage>
    with SingleTickerProviderStateMixin {
  static const Color kNavy = Color(0xFF1A2340);
  static const Color kYellow = Color(0xFFFFCC00);
  static const Color kBackground = Color(0xFFEEF0F5);

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final Set<String> _notifiedRides = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _listenForAcceptedRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: initSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void _listenForAcceptedRides() {
    FirebaseFirestore.instance
        .collection('rides')
        .where('riderId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final rideId = change.doc.id;
          if (data != null && !_notifiedRides.contains(rideId)) {
            if (data['status'] == 'accepted') {
              _showNotification(
                'Your ride from ${data['from']} to ${data['to']} has been accepted!',
              );
              _notifiedRides.add(rideId);
            }
          }
        }
      }
    });
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'ride_updates',
      'Ride Updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails details =
    NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Ride Update 🚗',
      message,
      details,
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return "Not set";
    if (dateTime is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toDate());
    }
    if (dateTime is DateTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    }
    return "Invalid date";
  }

  double _getDouble(dynamic val, {bool isLat = true}) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    if (val is GeoPoint) return isLat ? val.latitude : val.longitude;
    return 0.0;
  }

  Future<void> _markRideCompleted(String rideId, bool isPoster) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 22),
            ),
            const SizedBox(width: 12),
            const Text("Complete Ride?",
                style: TextStyle(
                    color: kNavy, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Both parties must confirm for the ride to be fully completed.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final rideRef =
      FirebaseFirestore.instance.collection('rides').doc(rideId);
      final doc = await rideRef.get();

      if (!doc.exists) {
        _showError("Ride not found");
        return;
      }

      final data = doc.data()!;
      final posterCompleted = data['posterCompleted'] ?? false;
      final accepterCompleted = data['accepterCompleted'] ?? false;

      if ((isPoster && posterCompleted) || (!isPoster && accepterCompleted)) {
        _showInfo("You've already marked this ride as completed.");
        return;
      }

      await rideRef.update({
        isPoster ? 'posterCompleted' : 'accepterCompleted': true,
      });

      final updatedDoc = await rideRef.get();
      final updated = updatedDoc.data()!;
      final bothCompleted = (updated['posterCompleted'] ?? false) &&
          (updated['accepterCompleted'] ?? false);

      if (bothCompleted) {
        await rideRef.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        _showSuccess("✅ Ride successfully completed by both parties!");
        await _showNotification("✅ Ride completed successfully!");
      } else {
        _showSuccess(
          isPoster
              ? "Marked as completed. Waiting for the rider to confirm..."
              : "Marked as completed. Waiting for the driver to confirm...",
        );
      }
    } catch (e) {
      _showError("Failed to mark ride as completed: $e");
    }
  }

  Future<void> _cancelRide(String rideId, bool isPoster) async {
    try {
      final rideRef =
      FirebaseFirestore.instance.collection('rides').doc(rideId);
      final doc = await rideRef.get();

      if (!doc.exists) {
        _showError("Ride not found");
        return;
      }

      final data = doc.data()!;
      final posterCancelled = data['posterCancelled'] ?? false;
      final accepterCancelled = data['accepterCancelled'] ?? false;

      if ((isPoster && posterCancelled) || (!isPoster && accepterCancelled)) {
        _showInfo("You've already marked this ride as cancelled.");
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              const Text("Cancel Ride?",
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
          content: Text(
            isPoster
                ? "You're about to cancel this ride. The accepter must also confirm to fully cancel it."
                : "You're about to cancel your participation. The poster must also confirm to fully cancel it.",
            style:
            TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("No", style: TextStyle(color: Colors.grey.shade500)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Yes, Cancel"),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await rideRef.update({
        isPoster ? 'posterCancelled' : 'accepterCancelled': true,
      });

      final updatedDoc = await rideRef.get();
      final updated = updatedDoc.data()!;
      final posterNow = updated['posterCancelled'] ?? false;
      final accepterNow = updated['accepterCancelled'] ?? false;

      if (posterNow && accepterNow) {
        await rideRef.update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        _showSuccess("🚫 Ride fully cancelled by both parties.");
        await _showNotification("🚫 Ride cancelled.");
      } else {
        _showSuccess(
          isPoster
              ? "You cancelled. Waiting for rider to confirm..."
              : "You cancelled. Waiting for driver to confirm...",
        );
      }
    } catch (e) {
      _showError("Failed to cancel ride: $e");
    }
  }

  void _openTrackingPage(
      Map<String, dynamic> rideData, String rideId, bool isDriver) {
    final startLat = _getDouble(rideData['from_lat']);
    final startLng = _getDouble(rideData['from_lng'], isLat: false);
    final destLat = _getDouble(rideData['to_lat']);
    final destLng = _getDouble(rideData['to_lng'], isLat: false);

    if (startLat == 0 || startLng == 0 || destLat == 0 || destLng == 0) {
      _showError("Invalid ride coordinates");
      return;
    }

    if (isDriver) {
      FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .update({'status': 'tracking'});
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRideTrackingPage(
          rideId: rideId,
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          isDriver: isDriver,
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildStatusChip(String status, Map<String, dynamic> rideData) {
    final posterCompleted = rideData['posterCompleted'] ?? false;
    final accepterCompleted = rideData['accepterCompleted'] ?? false;
    final posterCancelled = rideData['posterCancelled'] ?? false;
    final accepterCancelled = rideData['accepterCancelled'] ?? false;

    Color color;
    Color bgColor;
    String text = status.toUpperCase();

    switch (status) {
      case 'pending':
        color = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        break;
      case 'accepted':
        color = const Color(0xFF1565C0);
        bgColor = const Color(0xFFE3F2FD);
        if (posterCompleted && !accepterCompleted) {
          text = 'DRIVER ✓';
        } else if (!posterCompleted && accepterCompleted) {
          text = 'RIDER ✓';
        }
        if (posterCancelled || accepterCancelled) {
          color = Colors.redAccent;
          bgColor = const Color(0xFFFFEBEE);
          text = 'CANCEL PENDING';
        }
        break;
      case 'tracking':
        color = const Color(0xFF6A1B9A);
        bgColor = const Color(0xFFF3E5F5);
        text = 'TRACKING';
        break;
      case 'in_progress':
        color = const Color(0xFF00695C);
        bgColor = const Color(0xFFE0F2F1);
        text = 'IN PROGRESS';
        break;
      case 'completed':
        color = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFE8F5E9);
        break;
      case 'cancelled':
        color = Colors.redAccent;
        bgColor = const Color(0xFFFFEBEE);
        break;
      default:
        color = Colors.grey.shade600;
        bgColor = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildAppBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostedRides(),
                _buildAcceptedRides(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
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
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car, color: kNavy, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            "Your Rides",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1826),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: kYellow,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: kNavy,
          unselectedLabelColor: Colors.white,
          labelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 16),
                  SizedBox(width: 6),
                  Text("Posted"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16),
                  SizedBox(width: 6),
                  Text("Accepted"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
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
            child: Icon(icon, size: 48, color: kNavy),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  color: kNavy, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPostedRides() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .where('riderId', isEqualTo: widget.userId)
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNavy));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(Icons.directions_car_outlined,
              "No posted rides yet", "Tap + to post a ride!");
        }

        final rides = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final rideData =
                rides[index].data() as Map<String, dynamic>? ?? {};
            final status = (rideData['status'] ?? 'pending').toString();
            final rideId = rides[index].id;
            final acceptedBy = rideData['acceptedBy'];
            final acceptedByList =
            List<String>.from(rideData['acceptedByList'] ?? []);
            final hasAnyAcceptances =
                acceptedBy != null || acceptedByList.isNotEmpty;
            final totalSeats = rideData['seats'] ?? 0;
            final remainingSeats = rideData['remainingSeats'] ?? totalSeats;

            return _buildRideCard(
              rideData: rideData,
              status: status,
              rideId: rideId,
              isPoster: true,
              hasAnyAcceptances: hasAnyAcceptances,
              totalSeats: totalSeats,
              remainingSeats: remainingSeats,
              acceptedByList: acceptedByList,
              acceptedBy: acceptedBy,
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedRides() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNavy));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return _emptyState(Icons.car_rental_outlined,
              "No accepted rides yet", "Browse available rides!");
        }

        final rides = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          if (!['pending', 'accepted', 'tracking', 'in_progress', 'completed', 'cancelled']
              .contains(status)) return false;
          final riderId = widget.userId;
          final acceptedBy = data['acceptedBy'];
          final acceptedByList = List<String>.from(data['acceptedByList'] ?? []);
          return acceptedBy == riderId || acceptedByList.contains(riderId);
        }).toList();

        if (rides.isEmpty) {
          return _emptyState(Icons.car_rental_outlined,
              "No accepted rides yet", "Browse available rides!");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final rideData =
                rides[index].data() as Map<String, dynamic>? ?? {};
            final status = (rideData['status'] ?? 'pending').toString();
            final rideId = rides[index].id;
            final postedByName = rideData['postedByName'] ?? 'Unknown';

            return _buildRideCard(
              rideData: rideData,
              status: status,
              rideId: rideId,
              isPoster: false,
              postedByName: postedByName,
            );
          },
        );
      },
    );
  }

  Widget _buildRideCard({
    required Map<String, dynamic> rideData,
    required String status,
    required String rideId,
    required bool isPoster,
    bool hasAnyAcceptances = false,
    int totalSeats = 0,
    int remainingSeats = 0,
    List<String>? acceptedByList,
    dynamic acceptedBy,
    String? postedByName,
  }) {
    Color accentColor;
    if (status == 'completed') {
      accentColor = Colors.green;
    } else if (status == 'cancelled') {
      accentColor = Colors.redAccent;
    } else {
      accentColor = kYellow;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Colored top bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
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
                            width: 2, height: 22, color: Colors.grey.shade200),
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
                            rideData['from'] ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kNavy,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            rideData['to'] ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kNavy,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(status, rideData),
                  ],
                ),

                const SizedBox(height: 12),
                Container(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),

                // Meta row
                Row(
                  children: [
                    // Seats
                    _MetaChip(
                      icon: Icons.event_seat_outlined,
                      label: isPoster
                          ? "$remainingSeats/$totalSeats seats"
                          : "${rideData['seats'] ?? 0} seats",
                    ),
                    const SizedBox(width: 8),
                    // Time
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDateTime(rideData['dateTime']),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Driver name (for accepted rides)
                if (!isPoster && postedByName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: kYellow.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, size: 12, color: kNavy),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Driver: $postedByName",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                // Acceptance count
                if (isPoster && hasAnyAcceptances) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 13, color: Colors.green),
                      const SizedBox(width: 5),
                      Text(
                        "${(acceptedByList?.length ?? 0) + (acceptedBy != null ? 1 : 0)} accepted",
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildActionButtons(
                    status: status,
                    rideId: rideId,
                    rideData: rideData,
                    isPoster: isPoster,
                    hasAnyAcceptances: hasAnyAcceptances,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons({
    required String status,
    required String rideId,
    required Map<String, dynamic> rideData,
    required bool isPoster,
    bool hasAnyAcceptances = false,
  }) {
    List<Widget> buttons = [];

    if ((isPoster &&
        (['accepted', 'in_progress', 'tracking'].contains(status) ||
            hasAnyAcceptances)) ||
        (!isPoster && ['accepted', 'in_progress', 'tracking'].contains(status))) {
      buttons.add(_buildActionButton(
        icon: Icons.rocket_launch_rounded,
        label: status == 'accepted' ? "Start Ride" : "Active Ride",
        color: kNavy,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RideActivePage(
              rideId: rideId,
              userId: widget.userId,
              isDriver: isPoster,
            ),
          ),
        ),
      ));
    }

    if ((isPoster && ['pending', 'accepted', 'tracking'].contains(status)) ||
        (!isPoster && ['accepted', 'pending'].contains(status))) {
      buttons.add(_buildActionButton(
        icon: Icons.cancel_outlined,
        label: "Cancel",
        color: Colors.redAccent,
        isOutlined: true,
        onPressed: () => _cancelRide(rideId, isPoster),
      ));
    }

    if (['accepted', 'tracking'].contains(status)) {
      buttons.add(_buildActionButton(
        icon: Icons.check_circle_outline,
        label: "Done",
        color: Colors.green,
        isOutlined: true,
        onPressed: () => _markRideCompleted(rideId, isPoster),
      ));
    }

    return buttons;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isOutlined ? color.withOpacity(0.08) : color,
          borderRadius: BorderRadius.circular(10),
          border: isOutlined ? Border.all(color: color.withOpacity(0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isOutlined ? color : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isOutlined ? color : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable meta chip ────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2340).withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF1A2340)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A2340),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}