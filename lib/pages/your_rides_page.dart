import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'chat_page.dart';
import 'live_ride_tracking_page.dart';

class YourRidesPage extends StatefulWidget {
  final String userId;
  const YourRidesPage({required this.userId, Key? key}) : super(key: key);

  @override
  State<YourRidesPage> createState() => _YourRidesPageState();
}

class _YourRidesPageState extends State<YourRidesPage>
    with SingleTickerProviderStateMixin {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final Set<String> _notifiedRides = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _listenForAcceptedRides();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'ride_updates',
      'Ride Updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Ride Update 🚗',
      message,
      platformChannelSpecifics,
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
        backgroundColor: const Color(0xFF1E3C72).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Complete Ride?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to mark this ride as completed? "
              "Both parties must confirm for the ride to be fully completed.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: const Color(0xFF1E3C72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

      if ((isPoster && posterCancelled) ||
          (!isPoster && accepterCancelled)) {
        _showInfo("You've already marked this ride as cancelled.");
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E3C72).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Cancel Ride?",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            isPoster
                ? "You're about to cancel this ride. The accepter must also confirm to fully cancel it."
                : "You're about to cancel your participation. The poster must also confirm to fully cancel it.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "No",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    // When driver starts tracking, update Firestore
    if (isDriver) {
      FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'status': 'tracking',
      });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 15)),
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
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatusChip(String status, Map<String, dynamic> rideData) {
    final posterCompleted = rideData['posterCompleted'] ?? false;
    final accepterCompleted = rideData['accepterCompleted'] ?? false;
    final posterCancelled = rideData['posterCancelled'] ?? false;
    final accepterCancelled = rideData['accepterCancelled'] ?? false;

    Color color;
    String text = status.toUpperCase();

    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'accepted':
        color = Colors.blue;
        if (posterCompleted && !accepterCompleted) {
          text = 'ACCEPTED (Driver ✓)';
        } else if (!posterCompleted && accepterCompleted) {
          text = 'ACCEPTED (Rider ✓)';
        }
        if (posterCancelled && !accepterCancelled) {
          text = 'CANCEL PENDING (Driver)';
          color = Colors.red.shade300;
        } else if (!posterCancelled && accepterCancelled) {
          text = 'CANCEL PENDING (Rider)';
          color = Colors.red.shade300;
        }
        break;
      case 'tracking':
        color = Colors.purple;
        text = 'TRACKING';
        break;
      case 'in_progress':
        color = Colors.teal;
        text = 'IN PROGRESS';
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient Background
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

            // Animated Background Circles
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Custom App Bar
                      _buildCustomAppBar(),

                      // Tab Bar
                      _buildGlassmorphicTabBar(),

                      // Content
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildPostedRides(),
                            _buildAcceptedRides(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),

          // Car Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          const Text(
            "Your Rides",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF1E3C72),
        unselectedLabelColor: Colors.white,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 18),
                SizedBox(width: 6),
                Text("Posted"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 18),
                SizedBox(width: 6),
                Text("Accepted"),
              ],
            ),
          ),
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
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white.withOpacity(0.8),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No posted rides yet",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tap + to post a ride!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        final rides = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
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
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white.withOpacity(0.8),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              "No data available",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final rides = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();

          if (![
            'pending',
            'accepted',
            'tracking',
            'in_progress',
            'completed',
            'cancelled'
          ].contains(status)) {
            return false;
          }

          final riderId = widget.userId;
          final acceptedBy = data['acceptedBy'];
          final acceptedByList =
          List<String>.from(data['acceptedByList'] ?? []);

          return acceptedBy == riderId || acceptedByList.contains(riderId);
        }).toList();

        if (rides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.car_rental_outlined,
                    size: 64,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No accepted rides yet",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Browse available rides!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: status == "completed"
            ? Colors.green.withOpacity(0.15)
            : status == "cancelled"
            ? Colors.red.withOpacity(0.15)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trip_origin,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rideData['from'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // To Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rideData['to'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status and Seats
            Row(
              children: [
                _buildStatusChip(status, rideData),
                const SizedBox(width: 10),
                if (isPoster)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "$remainingSeats/$totalSeats seats",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "${rideData['seats'] ?? 0} seats",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Driver Name (for accepted rides)
            if (!isPoster && postedByName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Driver: $postedByName",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Departure Time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDateTime(rideData['dateTime']),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            // Acceptance Info
            if (isPoster && hasAnyAcceptances) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.greenAccent.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${(acceptedByList?.length ?? 0) + (acceptedBy != null ? 1 : 0)} accepted",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.greenAccent.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
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

    // Track Button
    if ((isPoster && (['accepted', 'tracking', 'in_progress'].contains(status) || hasAnyAcceptances)) ||
        (!isPoster && ['accepted', 'tracking', 'in_progress'].contains(status))) {
      buttons.add(
        _buildActionButton(
          icon: Icons.map,
          label: "Track",
          color: Colors.purple,
          onPressed: () => _openTrackingPage(rideData, rideId, isPoster),
        ),
      );
    }

    // Chat Button
    if ((isPoster && (hasAnyAcceptances || ['accepted', 'tracking', 'in_progress'].contains(status))) ||
        (!isPoster && ['accepted', 'pending', 'tracking', 'in_progress'].contains(status))) {
      buttons.add(
        _buildActionButton(
          icon: Icons.chat,
          label: "Chat",
          color: Colors.blue,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatPage(rideId: rideId)),
            );
          },
        ),
      );
    }

    // Cancel Button
    if ((isPoster && ['pending', 'accepted', 'tracking'].contains(status)) ||
        (!isPoster && ['accepted', 'pending'].contains(status))) {
      buttons.add(
        _buildActionButton(
          icon: Icons.cancel,
          label: "Cancel",
          color: Colors.red,
          onPressed: () => _cancelRide(rideId, isPoster),
        ),
      );
    }

    // Done Button
    if (['accepted', 'tracking'].contains(status)) {
      buttons.add(
        _buildActionButton(
          icon: Icons.check_circle,
          label: "Done",
          color: Colors.green,
          onPressed: () => _markRideCompleted(rideId, isPoster),
        ),
      );
    }

    return buttons;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}