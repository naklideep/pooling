import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'chat_page.dart';

class YourRidesPage extends StatefulWidget {
  final String userId;
  const YourRidesPage({required this.userId, Key? key}) : super(key: key);

  @override
  State<YourRidesPage> createState() => _YourRidesPageState();
}

class _YourRidesPageState extends State<YourRidesPage> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

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
        final data = change.doc.data();
        if (data != null && data['status'] == 'accepted') {
          _showNotification(
            'Your ride from ${data['from']} to ${data['to']} has been accepted!',
          );
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
      0,
      'Ride Update 🚗',
      message,
      platformChannelSpecifics,
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  /// 🧩 Mark ride completed for either poster or accepter
  Future<void> _markRideCompleted(String rideId, bool isPoster) async {
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    final doc = await rideRef.get();
    final data = doc.data();

    if (data == null) return;

    final posterCompleted = data['posterCompleted'] ?? false;
    final accepterCompleted = data['accepterCompleted'] ?? false;

    // Update respective field
    if (isPoster) {
      await rideRef.update({'posterCompleted': true});
    } else {
      await rideRef.update({'accepterCompleted': true});
    }

    // Re-fetch after update to check both sides
    final updatedDoc = await rideRef.get();
    final updated = updatedDoc.data();
    if (updated == null) return;

    final bothCompleted = (updated['posterCompleted'] ?? false) &&
        (updated['accepterCompleted'] ?? false);

    if (bothCompleted) {
      await rideRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bothCompleted
              ? "✅ Ride fully completed!"
              : isPoster
              ? "You marked this ride as completed. Waiting for accepter..."
              : "You marked this ride as completed. Waiting for poster...",
        ),
      ),
    );
  }

  /// ❌ Cancel ride (for pending rides)
  Future<void> _cancelRide(String rideId) async {
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    await rideRef.update({'status': 'cancelled'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚫 Ride cancelled successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Rides"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Posted Rides"),
              Tab(text: "Accepted Rides"),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rides = snapshot.data!.docs;
                if (rides.isEmpty) {
                  return const Center(child: Text("No posted rides yet."));
                }

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData =
                        rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'pending';
                    final acceptedByName = rideData['acceptedByName'] ?? '';
                    final posterCompleted =
                        rideData['posterCompleted'] ?? false;
                    final accepterCompleted =
                        rideData['accepterCompleted'] ?? false;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car,
                            color: Colors.blue),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: $status"),
                            Text(
                              "Posted: ${_formatTimestamp(rideData['timestamp'])}",
                            ),
                            if (acceptedByName.isNotEmpty)
                              Text("Accepted by: $acceptedByName"),
                            if (posterCompleted || accepterCompleted)
                              Text(
                                "Completion: ${posterCompleted ? 'Poster ✅' : 'Poster ❌'} | ${accepterCompleted ? 'Accepter ✅' : 'Accepter ❌'}",
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🟠 Cancel for pending rides
                            if (status == "pending")
                              IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: Colors.redAccent),
                                tooltip: "Cancel Ride",
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Cancel Ride?"),
                                      content: const Text(
                                          "Are you sure you want to cancel this ride?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("No"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("Yes"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _cancelRide(rides[index].id);
                                  }
                                },
                              ),
                            if (status == "accepted" || status == "completed")
                              IconButton(
                                icon:
                                const Icon(Icons.chat, color: Colors.blue),
                                tooltip: "Chat",
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatPage(rideId: rides[index].id),
                                    ),
                                  );
                                },
                              ),
                            if (status == "accepted" && !posterCompleted)
                              IconButton(
                                icon: const Icon(Icons.done,
                                    color: Colors.orange),
                                tooltip: "Mark as Completed",
                                onPressed: () async {
                                  await _markRideCompleted(
                                      rides[index].id, true);
                                },
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
                  .where('acceptedBy', isEqualTo: widget.userId)
                  .where('status',
                  whereIn: ['accepted', 'completed', 'expired'])
                  .orderBy("acceptedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No accepted rides yet."));
                }

                final rides = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData =
                        rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'pending';
                    final postedByName =
                        rideData['postedByName'] ?? 'Unknown';
                    final posterCompleted =
                        rideData['posterCompleted'] ?? false;
                    final accepterCompleted =
                        rideData['accepterCompleted'] ?? false;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car,
                            color: Colors.green),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: $status"),
                            Text("Posted by: $postedByName"),
                            Text(
                                "Accepted: ${_formatTimestamp(rideData['acceptedAt'])}"),
                            if (posterCompleted || accepterCompleted)
                              Text(
                                "Completion: ${posterCompleted ? 'Poster ✅' : 'Poster ❌'} | ${accepterCompleted ? 'Accepter ✅' : 'Accepter ❌'}",
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.blue),
                              tooltip: "Chat",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                        rideId: rides[index].id),
                                  ),
                                );
                              },
                            ),
                            if (status == "accepted" && !accepterCompleted)
                              IconButton(
                                icon: const Icon(Icons.done,
                                    color: Colors.orange),
                                tooltip: "Complete Ride",
                                onPressed: () async {
                                  await _markRideCompleted(
                                      rides[index].id, false);
                                },
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
