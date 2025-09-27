import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String name = "";
  String enrollment = "";
  String email = "";
  String contact = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          name = doc["name"];
          enrollment = doc["enrollment"];
          email = doc["email"];
          contact = doc["contact"];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Profile")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 60),
              ),
            ),
            SizedBox(height: 30),
            Text("Name: $name",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text("Enrollment: $enrollment",
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text("Email: $email", style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text("Contact: $contact", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
