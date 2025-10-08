import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'post_ride.dart';
import 'chat_page.dart';
import 'post_ride_widget.dart';
import 'find_ride_widget.dart';
import 'your_rides_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String userName = "User";
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userName = doc["name"] ?? "User";
        });
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
    );
  }

  void _onTabChanged(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return LoginPage();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Dashboard"),
          bottom: TabBar(
            onTap: _onTabChanged,
            tabs: [
              Tab(text: "Post Ride"),
              Tab(text: "Find Ride"),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.blue),
                    ),
                    SizedBox(height: 10),
                    Text("Welcome, $userName",
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    Text("MENU",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text("Profile"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ProfilePage()));
                },
              ),
              ListTile(
                leading: Icon(Icons.directions_car),
                title: Text("Your Rides"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => YourRidesPage(userId: user.uid)),
                  );
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text("Logout"),
                onTap: _logout,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PostRidePage(),
            FindRideWidget(userId: user.uid),
          ],
        ),
      ),
    );
  }
}
