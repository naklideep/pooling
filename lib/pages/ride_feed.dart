import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // ✅ for date formatting
import 'ride_card.dart';

class RideFeedPage extends StatelessWidget {
  const RideFeedPage({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Available Rides")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No rides available 🚘"));
          }

          final rides = snapshot.data!.docs;

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
              final rideId = rides[index].id;

              // 🕓 format timestamp before sending to RideCard
              final formattedTime = _formatTimestamp(rideData['timestamp']);
              rideData['formattedTime'] = formattedTime; // add new key

              return RideCard(
                rideData: rideData,
                rideId: rideId,
                currentUserId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}
