import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class FindRideWidget extends StatelessWidget {
  final String userId;
  FindRideWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final rides = snapshot.data!.docs;
        if (rides.isEmpty) return Center(child: Text("No rides available yet."));

        return ListView.builder(
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];
            final rideData = ride.data() as Map<String, dynamic>? ?? {};
            final status = rideData['status'] ?? 'pending';

            return Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                leading: Icon(Icons.directions_car, color: Colors.blue),
                title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                subtitle: Text("Seats: ${rideData['seats']}"),
                trailing: rideData['riderId'] == userId
                    ? Text("Your Ride", style: TextStyle(color: Colors.grey))
                    : status == "accepted"
                    ? Text("Accepted ✅", style: TextStyle(color: Colors.green))
                    : ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection("rides")
                        .doc(ride.id)
                        .update({
                      "status": "accepted",
                      "acceptedBy": userId,
                      "acceptedAt": FieldValue.serverTimestamp(),
                      "acceptedByName": "Passenger",
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Ride accepted!")));

                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatPage(rideId: ride.id)));
                  },
                  child: Text("Accept & Chat"),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
