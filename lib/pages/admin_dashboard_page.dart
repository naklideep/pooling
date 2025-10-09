import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // for date formatting

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate; // 🟢 store filter date

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

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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

  // 🧾 Overview Tab
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
            Text(title,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(count.toString(),
                style:
                const TextStyle(fontSize: 22, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 🚗 Manage Rides with Date Filter
  Widget _buildManageRidesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDate == null
                      ? "Filter by date"
                      : "Showing rides on ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(context),
              ),
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedDate = null),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rides')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allRides = snapshot.data!.docs;

              // 🔎 Filter rides by selected date (using Timestamp)
              final rides = _selectedDate == null
                  ? allRides
                  : allRides.where((ride) {
                final data = ride.data() as Map<String, dynamic>;
                final Timestamp? ts = data['dateTime'];
                if (ts == null) return false;
                final rideDate = ts.toDate();
                return rideDate.year == _selectedDate!.year &&
                    rideDate.month == _selectedDate!.month &&
                    rideDate.day == _selectedDate!.day;
              }).toList();

              if (rides.isEmpty) {
                return const Center(child: Text("No rides found"));
              }

              return ListView.builder(
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  final data = rides[index].data() as Map<String, dynamic>;
                  final Timestamp? ts = data['dateTime'];
                  final dateTime = ts?.toDate();
                  final formattedDate = dateTime != null
                      ? DateFormat('yyyy-MM-dd hh:mm a').format(dateTime)
                      : 'N/A';

                  return Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.directions_car,
                          color: Colors.blue),
                      title: Text("${data['from']} → ${data['to']}"),
                      subtitle: Text(
                          "Date: $formattedDate | Status: ${data['status'] ?? 'unknown'}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon:
                            const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRide(rides[index].id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.orange),
                            onPressed: () => _cancelRide(rides[index].id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 👤 Manage Users
  Widget _buildManageUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(child: Text("No users registered"));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final isBanned = user['isBanned'] ?? false;

            return Card(
              margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(Icons.person,
                    color: isBanned ? Colors.red : Colors.green),
                title: Text(user['name'] ?? "Unnamed User"),
                subtitle: Text(user['email'] ?? "No Email"),
                trailing: TextButton(
                  onPressed: () =>
                      _toggleBanUser(users[index].id, isBanned),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Ride deleted")));
  }

  Future<void> _cancelRide(String rideId) async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .update({'status': 'cancelled'});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Ride cancelled")));
  }

  Future<void> _toggleBanUser(String userId, bool isBanned) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isBanned': !isBanned});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isBanned ? "User unbanned" : "User banned")));
  }
}
