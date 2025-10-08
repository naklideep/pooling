import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Rides"),
            Tab(text: "Users"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildManageRidesTab(),
          _buildManageUsersTab(),
        ],
      ),
    );
  }

  // 🟢 Overview: show quick stats
  Widget _buildOverviewTab() {
    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('rides').get(),
      ]),
      builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final totalUsers = snapshot.data![0].size;
        final totalRides = snapshot.data![1].size;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard("Total Users", totalUsers, Icons.person),
              _buildStatCard("Total Rides", totalRides, Icons.directions_car),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(count.toString(), style: const TextStyle(fontSize: 22, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 🚗 Manage Rides
  Widget _buildManageRidesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rides = snapshot.data!.docs;

        if (rides.isEmpty) return const Center(child: Text("No rides found"));

        return ListView.builder(
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final data = rides[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.directions_car, color: Colors.blue),
                title: Text("${data['from']} → ${data['to']}"),
                subtitle: Text("Status: ${data['status'] ?? 'unknown'}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRide(rides[index].id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.orange),
                      onPressed: () => _cancelRide(rides[index].id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 👤 Manage Users
  Widget _buildManageUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs;

        if (users.isEmpty) return const Center(child: Text("No users registered"));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final isBanned = user['isBanned'] ?? false;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(Icons.person, color: isBanned ? Colors.red : Colors.green),
                title: Text(user['name'] ?? "Unnamed User"),
                subtitle: Text(user['email'] ?? "No Email"),
                trailing: TextButton(
                  onPressed: () => _toggleBanUser(users[index].id, isBanned),
                  child: Text(isBanned ? "Unban" : "Ban"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔧 Admin actions
  Future<void> _deleteRide(String rideId) async {
    await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride deleted")),
    );
  }

  Future<void> _cancelRide(String rideId) async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .update({'status': 'cancelled'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride cancelled")),
    );
  }

  Future<void> _toggleBanUser(String userId, bool isBanned) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isBanned': !isBanned});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isBanned ? "User unbanned" : "User banned")),
    );
  }
}
