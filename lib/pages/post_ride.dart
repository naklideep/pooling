import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostRidePage extends StatefulWidget {
  const PostRidePage({super.key});

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // ✅ Fetch username (from Firestore or fallback)
      String userName = "Unknown";
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['name'] != null) {
        userName = userDoc['name'];
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null && user.email!.contains('@')) {
        userName = user.email!.split('@').first;
      }

      // ✅ Save ride data with all expected fields
      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'seats': int.tryParse(_seatsController.text.trim()) ?? 1,
        'date': _dateController.text.trim(),
        'time': _timeController.text.trim(),
        'status': 'pending',
        'riderId': user.uid,           // same naming as find_ride_widget
        'postedByName': userName,      // rider name shown in ride feed
        'acceptedBy': '',              // will be updated when accepted
        'acceptedByName': '',          // will store acceptor name
        'acceptedAt': null,            // timestamp when accepted
        'completedAt': null,           // future use
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Ride posted successfully by $userName")),
      );

      _formKey.currentState!.reset();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error posting ride: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Ride"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fromController,
                decoration: const InputDecoration(labelText: "From"),
                validator: (v) => v!.isEmpty ? "Enter source" : null,
              ),
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(labelText: "To"),
                validator: (v) => v!.isEmpty ? "Enter destination" : null,
              ),
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(labelText: "Available Seats"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter number of seats" : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration:
                const InputDecoration(labelText: "Date (e.g. 2025-10-07)"),
                validator: (v) => v!.isEmpty ? "Enter date" : null,
              ),
              TextFormField(
                controller: _timeController,
                decoration:
                const InputDecoration(labelText: "Time (e.g. 10:00 AM)"),
                validator: (v) => v!.isEmpty ? "Enter time" : null,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _isLoading ? null : _postRide,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Post Ride"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
