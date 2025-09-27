import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideFeedPage extends StatelessWidget {
  const RideFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              final ride = rides[index];
              final from = ride['from'] ?? "Unknown";
              final to = ride['to'] ?? "Unknown";
              final date = ride['date'] ?? "-";
              final time = ride['time'] ?? "-";
              final seats = ride['availableSeats'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blue),
                  title: Text("$from → $to",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Date: $date | Time: $time\nSeats: $seats"),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Later we add "Join Ride" logic here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ride request sent 🚀")),
                      );
                    },
                    child: const Text("Join"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
