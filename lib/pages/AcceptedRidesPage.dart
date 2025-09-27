// AcceptedRidesPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class AcceptedRidesPage extends StatelessWidget {
  final String userId;
  AcceptedRidesPage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Posted rides & Accepted rides
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
            // ------------------- Tab 1: Posted Rides -------------------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where('riderId', isEqualTo: userId)
                  .orderBy("timestamp", descending: true) // FIXED
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text("Error: ${snapshot.error}"));

                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final rides = snapshot.data!.docs;
                if (rides.isEmpty)
                  return Center(child: Text("You haven't posted any rides yet."));

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final status = rideData['status'] ?? 'open';
                    final seats = rideData['seats'] ?? 'N/A';
                    final acceptedByName = rideData['acceptedByName'] ?? '';

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.blue),
                        title: Text("${rideData['from'] ?? 'Unknown'} ➝ ${rideData['to'] ?? 'Unknown'}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: $seats"),
                            Text("Status: $status"),
                            if (rideData['acceptedBy'] != null)
                              Text("Accepted by: $acceptedByName"),
                          ],
                        ),
                        trailing: rideData['acceptedBy'] != null
                            ? ElevatedButton(
                          child: Text("Chat"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(rideId: rides[index].id),
                              ),
                            );
                          },
                        )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),

            // ------------------- Tab 2: Accepted Rides -------------------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where('acceptedBy', isEqualTo: userId)
                  .where('status', isEqualTo: 'accepted')
                  .orderBy("acceptedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text("Error: ${snapshot.error}"));

                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final rides = snapshot.data!.docs;
                if (rides.isEmpty)
                  return Center(child: Text("You haven't accepted any rides yet."));

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    final seats = rideData['seats'] ?? 'N/A';

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.green),
                        title: Text("${rideData['from'] ?? 'Unknown'} ➝ ${rideData['to'] ?? 'Unknown'}"),
                        subtitle: Text("Seats: $seats"),
                        trailing: ElevatedButton(
                          child: Text("Chat"),
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
