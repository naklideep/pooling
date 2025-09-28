import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostRideWidget extends StatefulWidget {
  final String userId;
  PostRideWidget({required this.userId});

  @override
  _PostRideWidgetState createState() => _PostRideWidgetState();
}

class _PostRideWidgetState extends State<PostRideWidget> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();

  void _postRide() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        seatsController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please fill all fields!")));
      return;
    }

    await FirebaseFirestore.instance.collection("rides").add({
      "from": fromController.text,
      "to": toController.text,
      "seats": seatsController.text,
      "riderId": widget.userId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Ride posted successfully ✅")));

    fromController.clear();
    toController.clear();
    seatsController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.directions_car, size: 80, color: Colors.green),
          SizedBox(height: 20),
          TextField(controller: fromController, decoration: InputDecoration(labelText: "From")),
          TextField(controller: toController, decoration: InputDecoration(labelText: "To")),
          TextField(
            controller: seatsController,
            decoration: InputDecoration(labelText: "Seats"),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 20),
          ElevatedButton(onPressed: _postRide, child: Text("Post Ride")),
        ],
      ),
    );
  }
}
