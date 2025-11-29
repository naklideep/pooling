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

class _YourRidesPageState extends State<YourRidesPage> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final Set<String> _notifiedRides = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _listenForAcceptedRides();
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
        title: const Text("Confirm Ride Completion"),
        content: const Text(
          "Are you sure you want to mark this ride as completed? "
              "Both parties must confirm for the ride to be fully completed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
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
      final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
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
          title: const Text("Cancel Ride?"),
          content: Text(
            isPoster
                ? "You're about to cancel this ride. The accepter must also confirm to fully cancel it."
                : "You're about to cancel your participation. The poster must also confirm to fully cancel it.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  void _openTrackingPage(Map<String, dynamic> rideData, String rideId, bool isDriver) {
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
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Rides"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.post_add), text: "Posted Rides"),
              Tab(icon: Icon(Icons.check_circle), text: "Accepted Rides"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ------------------ Posted Rides ------------------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where('riderId', isEqualTo: widget.userId)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No posted rides yet."),
                        Text("Tap + to post a ride!", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final rides = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = (rideData['status'] ?? 'pending').toString();
                    final rideId = rides[index].id;

                    final acceptedBy = rideData['acceptedBy'];
                    final acceptedByList = List<String>.from(rideData['acceptedByList'] ?? []);
                    final hasAnyAcceptances = acceptedBy != null || acceptedByList.isNotEmpty;

                    final totalSeats = rideData['seats'] ?? 0;
                    final remainingSeats = rideData['remainingSeats'] ?? totalSeats;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: status == "completed"
                          ? Colors.green.shade50
                          : status == "cancelled"
                          ? Colors.red.shade50
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rideData['from'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rideData['to'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildStatusChip(status, rideData),
                                const SizedBox(width: 8),
                                Text(
                                  "Seats: $remainingSeats/$totalSeats available",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Departure: ${_formatDateTime(rideData['dateTime'])}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (hasAnyAcceptances) ...[
                              const SizedBox(height: 4),
                              Text(
                                "✓ ${acceptedByList.length + (acceptedBy != null ? 1 : 0)} accepted",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (['accepted', 'tracking', 'in_progress'].contains(status) || hasAnyAcceptances)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.map, size: 16),
                                    label: const Text("Track", style: TextStyle(fontSize: 12)),
                                    onPressed: () => _openTrackingPage(rideData, rideId, true),
                                  ),
                                if (['pending', 'accepted', 'tracking'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text("Cancel", style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () => _cancelRide(rideId, true),
                                  ),
                                if (['accepted', 'tracking'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text("Done", style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                                    onPressed: () => _markRideCompleted(rideId, true),
                                  ),
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

            // ------------------ Accepted Rides ------------------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text("No data available"));
                }

                final rides = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString();

                  if (!['pending', 'accepted', 'completed', 'cancelled', 'tracking', 'in_progress'].contains(status)) {
                    return false;
                  }

                  final acceptedBy = data['acceptedBy'];
                  final acceptedByList = List<String>.from(data['acceptedByList'] ?? []);
                  final riderId = widget.userId;
                  final isRider = acceptedBy == riderId || acceptedByList.contains(riderId);
                  final isPoster = data['riderId'] == riderId;

                  return isRider || isPoster;
                }).toList();

                if (rides.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.car_rental_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No accepted rides yet."),
                        Text("Browse available rides!", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = (rideData['status'] ?? 'pending').toString();
                    final rideId = rides[index].id;
                    final postedByName = rideData['postedByName'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: status == "completed"
                          ? Colors.green.shade50
                          : status == "cancelled"
                          ? Colors.red.shade50
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rideData['from'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rideData['to'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildStatusChip(status, rideData),
                                const SizedBox(width: 8),
                                Text(
                                  "Seats: ${rideData['seats'] ?? 0}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Driver: $postedByName",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "Departure: ${_formatDateTime(rideData['dateTime'])}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (['accepted', 'tracking', 'in_progress'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.map, size: 16),
                                    label: const Text("Track", style: TextStyle(fontSize: 12)),
                                    onPressed: () => _openTrackingPage(rideData, rideId, false),
                                  ),
                                if (['accepted', 'pending'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text("Chat", style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatPage(rideId: rideId),
                                        ),
                                      );
                                    },
                                  ),
                                if (['accepted', 'pending'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text("Cancel", style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () => _cancelRide(rideId, false),
                                  ),
                                if (['accepted', 'tracking'].contains(status))
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text("Done", style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                                    onPressed: () => _markRideCompleted(rideId, false),
                                  ),
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
          ],
        ),
      ),
    );
  }
}
