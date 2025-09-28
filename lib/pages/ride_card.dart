import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class RideCard extends StatelessWidget {
  final Map<String, dynamic> rideData;
  final String rideId;
  final String currentUserId;

  RideCard({
    required this.rideData,
    required this.rideId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOwner = rideData['riderId'] == currentUserId;
    final String status = rideData['status'] ?? 'pending';
    final bool isAccepted = status == 'accepted';
    final bool isPending = status == 'pending';
    final bool isCancelled = status == 'cancelled';
    final bool isCompleted = status == 'completed';
    final int seats = int.tryParse(rideData['seats'].toString()) ?? 0;
    final String acceptedByName = rideData['acceptedByName'] ?? '';

    return Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- Ride Info ----------------
            ListTile(
              leading: Icon(
                Icons.directions_car,
                color: isAccepted
                    ? Colors.green
                    : (isPending ? Colors.blue : Colors.grey),
              ),
              title: Text("${rideData['from']} ➝ ${rideData['to']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Seats: $seats"),
                  Text("Status: $status"),
                  if (acceptedByName.isNotEmpty) Text("Accepted by: $acceptedByName"),
                  if (rideData['timestamp'] != null)
                    Text("Posted: ${(rideData['timestamp'] as Timestamp).toDate()}"),
                  if (rideData['acceptedAt'] != null)
                    Text("Accepted: ${(rideData['acceptedAt'] as Timestamp).toDate()}"),
                  if (rideData['completedAt'] != null)
                    Text("Completed: ${(rideData['completedAt'] as Timestamp).toDate()}"),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ---------------- Buttons ----------------
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Accept & Chat (for passengers)
                  if (!isOwner && isPending && !isCancelled)
                    ElevatedButton(
                      child: Text("Accept & Chat"),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser!;
                        final userDoc = await FirebaseFirestore.instance
                            .collection("users")
                            .doc(user.uid)
                            .get();
                        final userName = userDoc['name'] ?? 'Passenger';

                        await FirebaseFirestore.instance
                            .collection("rides")
                            .doc(rideId)
                            .update({
                          'status': 'accepted',
                          'acceptedBy': currentUserId,
                          'acceptedByName': userName,
                          'acceptedAt': FieldValue.serverTimestamp(),
                        });

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(rideId: rideId)),
                        );
                      },
                    ),

                  SizedBox(width: 8),

                  // Cancel Ride (for owner)
                  if (isOwner && isPending && !isCancelled)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text("Cancel Ride"),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("rides")
                            .doc(rideId)
                            .update({"status": "cancelled"});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Ride cancelled ❌")),
                        );
                      },
                    ),

                  SizedBox(width: 8),

                  // End Ride (for owner)
                  if (isOwner && isAccepted)
                    ElevatedButton(
                      style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: Text("End Ride"),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("rides")
                            .doc(rideId)
                            .update({
                          "status": "completed",
                          "completedAt": FieldValue.serverTimestamp(),
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Ride completed ✅")),
                        );
                      },
                    ),

                  SizedBox(width: 8),

                  // Chat (for accepted rides or owner)
                  if ((isAccepted && !isOwner) || (isOwner && !isPending && !isCancelled))
                    ElevatedButton(
                      child: Text("Chat"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatPage(rideId: rideId)),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
