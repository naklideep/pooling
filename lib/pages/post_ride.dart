import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // for formatting

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

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  // 🔹 Pick Date and Time together
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() => _selectedDateTime = combined);
  }

  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please select a date & time")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String userName = "Unknown";
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data()?['name'] != null) {
        userName = userDoc['name'];
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null && user.email!.contains('@')) {
        userName = user.email!.split('@').first;
      }

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromController.text.trim(),
        'to': _toController.text.trim(),
        'seats': int.tryParse(_seatsController.text.trim()) ?? 1,
        'dateTime': _selectedDateTime,
        'status': 'pending',
        'riderId': user.uid,
        'postedByName': userName,
        'acceptedBy': '',
        'acceptedByName': '',
        'acceptedAt': null,
        'completedAt': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Ride posted successfully by $userName")),
      );

      _formKey.currentState!.reset();
      setState(() => _selectedDateTime = null);
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
    final dateTimeText = _selectedDateTime == null
        ? "Pick Date & Time"
        : DateFormat('yyyy-MM-dd hh:mm a').format(_selectedDateTime!);

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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(dateTimeText),
                onPressed: _pickDateTime,
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
