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

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading:
                        const Icon(Icons.directions_car, color: Colors.blue),
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
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == "accepted")
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.blue),
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
                            if (status == "accepted")
                              IconButton(
                                icon: const Icon(Icons.done,
                                    color: Colors.orange),
                                tooltip: "End Ride",
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection("rides")
                                      .doc(rides[index].id)
                                      .update({
                                    "status": "completed",
                                    "completedAt": FieldValue.serverTimestamp(),
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Ride completed ✅")),
                                  );
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
                  .where('status', whereIn: ['accepted', 'completed', 'expired'])
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
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'pending';
                    final postedByName = rideData['postedByName'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.green),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: $status"),
                            Text("Posted by: $postedByName"),
                            Text("Accepted: ${_formatTimestamp(rideData['acceptedAt'])}"),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blue),
                          tooltip: "Chat",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(rideId: rides[index].id),
                              ),
                            );
                          },
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
