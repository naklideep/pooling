import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    bool isCancelled = rideData['status'] == 'cancelled';
    bool isOwner = rideData['userId'] == currentUserId;

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rideData['title'] ?? 'Ride',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(rideData['description'] ?? ''),
            SizedBox(height: 8),

            // Cancel button (only visible to ride owner and if not already cancelled)
            if (isOwner && !isCancelled)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => _confirmCancel(context, rideId),
                child: Text("Cancel Ride"),
              ),

            // Show cancelled status
            if (isCancelled)
              Text(
                "Cancelled",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String rideId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cancel Ride"),
        content: Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () {
              _cancelRide(rideId);
              Navigator.of(ctx).pop();
            },
            child: Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide(String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection("rides")
          .doc(rideId)
          .update({'status': 'cancelled'});

      print("Ride cancelled successfully!");
    } catch (e) {
      print("Error cancelling ride: $e");
    }
  }
}
