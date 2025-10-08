import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class YourRidesPage extends StatelessWidget {
  final String userId;
  YourRidesPage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Your Rides"),
          bottom: TabBar(
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
                  .where('riderId', isEqualTo: userId)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final rides = snapshot.data!.docs;
                if (rides.isEmpty) return Center(child: Text("No posted rides yet."));

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'pending';
                    final acceptedByName = rideData['acceptedByName'] ?? '';

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.blue),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: $status"),
                            if (acceptedByName.isNotEmpty)
                              Text("Accepted by: $acceptedByName"),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == "accepted")
                              IconButton(
                                icon: Icon(Icons.chat, color: Colors.blue),
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
                            if (status == "accepted")
                              IconButton(
                                icon: Icon(Icons.done, color: Colors.orange),
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
                                    SnackBar(content: Text("Ride completed ✅")),
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
                  .where('acceptedBy', isEqualTo: userId)
                  .where('status', isEqualTo: 'accepted')
                  .orderBy("acceptedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final rides = snapshot.data!.docs;
                if (rides.isEmpty) return Center(child: Text("No accepted rides yet."));

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'pending';
                    final postedByName = rideData['postedByName'] ?? 'Unknown';

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.green),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: $status"),
                            Text("Posted by: $postedByName"), // Added postedBy
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chat, color: Colors.blue),
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
                            if (status == "accepted")
                              IconButton(
                                icon: Icon(Icons.done, color: Colors.orange),
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
                                    SnackBar(content: Text("Ride completed ✅")),
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
          ],
        ),
      ),
    );
  }
}
