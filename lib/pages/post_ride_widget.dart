import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostRideWidget extends StatefulWidget {
  const PostRideWidget({super.key});

  @override
  State<PostRideWidget> createState() => _PostRideWidgetState();
}

class _PostRideWidgetState extends State<PostRideWidget> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final seatsController = TextEditingController();

  Future<void> _postRide() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in")),
      );
      return;
    }

    // ✅ Fetch username from 'users' collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final username = userDoc.data()?['name'] ?? 'Unknown';

    // ✅ Post ride with username included
    await FirebaseFirestore.instance.collection('rides').add({
      'from': fromController.text.trim(),
      'to': toController.text.trim(),
      'seats': seatsController.text.trim(),
      'riderId': user.uid,
      'postedByName': username, // 👈 important
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride posted successfully!")),
    );

    fromController.clear();
    toController.clear();
    seatsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(controller: fromController, decoration: const InputDecoration(labelText: "From")),
          TextField(controller: toController, decoration: const InputDecoration(labelText: "To")),
          TextField(controller: seatsController, decoration: const InputDecoration(labelText: "Seats")),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _postRide,
            child: const Text("Post Ride"),
          ),
        ],
      ),
    );
  }
}
