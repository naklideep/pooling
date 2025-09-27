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
    final bool isOwner = rideData['owner'] == currentUserId;
    final bool isAccepted = rideData['status'] == 'accepted';

    return Card(
      margin: EdgeInsets.all(10),
      child: ListTile(
        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
        subtitle: Text("Seats: ${rideData['availableSeats']}"),
        trailing: isOwner || isAccepted
            ? ElevatedButton(
          child: Text("Chat"),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatPage(rideId: rideId)));
          },
        )
            : ElevatedButton(
          child: Text("Accept & Chat"),
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('rides')
                  .doc(rideId)
                  .update({
                'status': 'accepted',
                'acceptedBy': currentUserId,
                'acceptedAt': FieldValue.serverTimestamp(),
              });
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatPage(rideId: rideId)));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")));
            }
          },
        ),
      ),
    );
  }
}
