import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class FindRideWidget extends StatelessWidget {
  final String userId;

  const FindRideWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter out cancelled rides
        final rides = snapshot.data!.docs
            .where((ride) =>
        (ride.data() as Map<String, dynamic>)['status'] != 'cancelled')
            .toList();

        if (rides.isEmpty) {
          return const Center(child: Text("No rides available yet 🚗"));
        }

        return ListView.builder(
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];
            final rideData = ride.data() as Map<String, dynamic>? ?? {};
            final status = rideData['status'] ?? 'pending';

            final from = rideData['from'] ?? "N/A";
            final to = rideData['to'] ?? "N/A";
            final seats = rideData['seats']?.toString() ?? "N/A";
            final riderName =
            rideData['postedByName']?.toString().trim().isNotEmpty ?? false
                ? rideData['postedByName']
                : "Unknown";

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.directions_car, color: Colors.blue),
                title: Text("$from ➝ $to",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Seats: $seats"),
                    Text("Posted by: $riderName"),
                  ],
                ),
                trailing:
                _buildTrailing(context, ride.id, rideData, status, riderName),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrailing(BuildContext context, String rideId,
      Map<String, dynamic> rideData, String status, String riderName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final currentUserName =
        currentUser?.displayName ?? currentUser?.email?.split('@').first ?? "User";

    // If ride belongs to current user
    if (rideData['riderId'] == currentUserId) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () => _confirmCancel(context, rideId),
        child: const Text("Cancel Ride"),
      );
    }

    // If already accepted
    if (status == "accepted") {
      final acceptedBy = rideData['acceptedByName'] ?? "Someone";
      return Text("Accepted by $acceptedBy ✅",
          style: const TextStyle(color: Colors.green));
    }

    // Otherwise show accept button
    return ElevatedButton(
      onPressed: () async {
        try {
          await FirebaseFirestore.instance
              .collection("rides")
              .doc(rideId)
              .update({
            "status": "accepted",
            "acceptedBy": currentUserId,
            "acceptedAt": FieldValue.serverTimestamp(),
            "acceptedByName": currentUserName,
          });

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ride accepted successfully ✅")));

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatPage(rideId: rideId)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error accepting ride: $e")));
        }
      },
      child: const Text("Accept & Chat"),
    );
  }

  void _confirmCancel(BuildContext context, String rideId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride"),
        content: const Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              _cancelRide(context, rideId);
              Navigator.of(ctx).pop();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide(BuildContext context, String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection("rides")
          .doc(rideId)
          .update({'status': 'cancelled'});

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride cancelled successfully ❌")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to cancel ride: $e")));
    }
  }
}
