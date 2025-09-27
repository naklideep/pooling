// dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'chat_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String userName = "User";
  int selectedIndex = 0;

  final pages = ["Post Ride", "Find Ride"];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
      await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
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
            PostRideWidget(userId: user.uid),
            FindRideWidget(userId: user.uid),
          ],
        ),
      ),
    );
  }
}

// ------------------- Post Ride Widget -------------------
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

// ------------------- Find Ride Widget -------------------
class FindRideWidget extends StatelessWidget {
  final String userId;
  FindRideWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final rides = snapshot.data!.docs;
        if (rides.isEmpty) return Center(child: Text("No rides available yet."));

        return ListView.builder(
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];
            final rideData = ride.data() as Map<String, dynamic>? ?? {};
            final status = rideData['status'] ?? 'pending';

            return Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                leading: Icon(Icons.directions_car, color: Colors.blue),
                title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                subtitle: Text("Seats: ${rideData['seats']}"),
                trailing: rideData['riderId'] == userId
                    ? Text("Your Ride", style: TextStyle(color: Colors.grey))
                    : status == "accepted"
                    ? Text("Accepted ✅", style: TextStyle(color: Colors.green))
                    : ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection("rides")
                        .doc(ride.id)
                        .update({
                      "status": "accepted",
                      "acceptedBy": userId,
                      "acceptedAt": FieldValue.serverTimestamp(),
                      "acceptedByName": "Passenger",
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Ride accepted!")));

                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatPage(rideId: ride.id)));
                  },
                  child: Text("Accept & Chat"),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------- Your Rides Page -------------------
class YourRidesPage extends StatelessWidget {
  final String userId;
  YourRidesPage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Posted & Accepted
      child: Scaffold(
        appBar: AppBar(
          title: Text("Your Rides"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Posted Rides"),
              Tab(text: "Accepted Rides"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Posted Rides
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where('riderId', isEqualTo: userId)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final rides = snapshot.data!.docs;
                if (rides.isEmpty) return Center(child: Text("No posted rides yet."));
                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.blue),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seats: ${rideData['seats']}"),
                            Text("Status: ${rideData['status']}"),
                            if (rideData['acceptedByName'] != null)
                              Text("Accepted by: ${rideData['acceptedByName']}"),
                          ],
                        ),
                        trailing: rideData['acceptedBy'] != null
                            ? ElevatedButton(
                          child: Text("Chat"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ChatPage(rideId: rides[index].id)),
                            );
                          },
                        )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),

            // Accepted Rides
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where('acceptedBy', isEqualTo: userId)
                  .where('status', isEqualTo: 'accepted')
                  .orderBy("acceptedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final rides = snapshot.data!.docs;
                if (rides.isEmpty) return Center(child: Text("No accepted rides yet."));
                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final rideData = rides[index].data() as Map<String, dynamic>? ?? {};
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.directions_car, color: Colors.green),
                        title: Text("${rideData['from']} ➝ ${rideData['to']}"),
                        subtitle: Text("Seats: ${rideData['seats']}"),
                        trailing: ElevatedButton(
                          child: Text("Chat"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatPage(rideId: rides[index].id)),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
