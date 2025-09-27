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
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();

  bool _isLoading = false;

  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'date': _dateController.text.trim(),
        'time': _timeController.text.trim(),
        'availableSeats': int.parse(_seatsController.text.trim()),
        'createdBy': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ride posted successfully ✅")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post a Ride")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fromController,
                decoration: const InputDecoration(labelText: "From"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter start location" : null,
              ),
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(labelText: "To"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter destination" : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: "Date (DD/MM/YYYY)"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter date" : null,
              ),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(labelText: "Time (HH:MM)"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter time" : null,
              ),
              TextFormField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Available Seats"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter seats";
                  if (int.tryParse(value) == null) return "Enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _postRide,
                child: const Text("Post Ride"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
