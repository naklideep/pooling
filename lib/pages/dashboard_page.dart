import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool showGetRide = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userName = "User";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          userName = doc["name"];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dashboard")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
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
                  Text(
                    "Welcome, $userName",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    "MENU!!!",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.directions_car),
              title: Text("Get Ride"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  showGetRide = true;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text("Find Ride"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  showGetRide = false;
                });
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
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showGetRide = true;
                  });
                },
                child: Text("Get Ride"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 40),
                  backgroundColor: showGetRide ? Colors.blue : Colors.grey,
                ),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showGetRide = false;
                  });
                },
                child: Text("Find Ride"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(120, 40),
                  backgroundColor: !showGetRide ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          Expanded(
            child: Center(
              child: showGetRide
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car,
                      size: 80, color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    "Get Ride Page Content",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search,
                      size: 80, color: Colors.orange),
                  SizedBox(height: 20),
                  Text(
                    "Find Ride Page Content",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
