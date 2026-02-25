import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Constants
class AdminConstants {
  static const int itemsPerPage = 20;
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const String adminRole = 'admin';
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filters & Search
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'timestamp';
  Timer? _searchDebounce;

  // Selection for bulk actions
  Set<String> _selectedRideIds = {};
  Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // REMOVED admin check - access for everyone for now
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 📝 AUDIT: Log admin actions
  Future<void> _logAdminAction(String action, Map<String, dynamic> details) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'adminId': user?.uid,
        'adminEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  // 📅 Date pickers
  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // 🔍 Search with debounce
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AdminConstants.searchDebounce, () {
      setState(() => _searchQuery = query.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_rides') _exportRides();
              if (value == 'export_users') _exportUsers();
              if (value == 'view_logs') _viewAuditLogs();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export_rides', child: Text('📊 Export Rides')),
              const PopupMenuItem(value: 'export_users', child: Text('👥 Export Users')),
              const PopupMenuItem(value: 'view_logs', child: Text('📜 View Audit Logs')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '📊 Overview'),
            Tab(text: '🚗 Rides'),
            Tab(text: '👤 Users'),
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

  // 📊 OVERVIEW TAB with real-time stats
  Widget _buildOverviewTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('rides').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> ridesSnapshot) {
        return StreamBuilder(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> usersSnapshot) {
            if (!ridesSnapshot.hasData || !usersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rides = ridesSnapshot.data!.docs;
            final users = usersSnapshot.data!.docs;

            // Calculate stats
            final totalRides = rides.length;
            final totalUsers = users.length;
            final activeRides = rides.where((r) =>
            (r.data() as Map)['status'] == 'pending').length;
            final completedToday = rides.where((r) {
              final data = r.data() as Map;
              final ts = data['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final date = ts.toDate();
              final now = DateTime.now();
              return data['status'] == 'completed' &&
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
            }).length;

            final carRides = rides.where((r) =>
            (r.data() as Map)['rideType'] == 'Car').length;
            final bikeRides = rides.where((r) =>
            (r.data() as Map)['rideType'] == 'Bike').length;

            final totalRevenue = rides.fold<double>(0, (sum, r) {
              final data = r.data() as Map;
              return sum + ((data['estimatedCost'] as num?)?.toDouble() ?? 0);
            });

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: _getGridColumns(context),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _buildStatCard('Total Users', totalUsers, Icons.person, Colors.blue),
                        _buildStatCard('Total Rides', totalRides, Icons.directions_car, Colors.green),
                        _buildStatCard('Active Rides', activeRides, Icons.pending, Colors.orange),
                        _buildStatCard('Completed Today', completedToday, Icons.check_circle, Colors.purple),
                        _buildStatCard('Car Rides', carRides, Icons.directions_car, Colors.teal),
                        _buildStatCard('Bike Rides', bikeRides, Icons.two_wheeler, Colors.indigo),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 24),
                    // Simple text-based analytics (no charts)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📈 Quick Stats',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const Divider(),
                            _buildStatRow('Pending Rides', activeRides.toString()),
                            _buildStatRow('Completed Rides',
                                rides.where((r) => (r.data() as Map)['status'] == 'completed').length.toString()),
                            _buildStatRow('Cancelled Rides',
                                rides.where((r) => (r.data() as Map)['status'] == 'cancelled').length.toString()),
                            _buildStatRow('Average Cost',
                                rides.isEmpty ? '₹0' : '₹${(totalRevenue / totalRides).toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(count.toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 🚗 MANAGE RIDES TAB
  Widget _buildManageRidesTab() {
    return Column(
      children: [
        _buildRideFilters(),
        if (_selectedRideIds.isNotEmpty) _buildRideBulkActions(),
        Expanded(child: _buildRidesList()),
      ],
    );
  }

  Widget _buildRideFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: '🔍 Search by location, user...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_startDate == null
                      ? 'Date Range'
                      : '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'),
                  onPressed: () => _pickDateRange(context),
                ),
                if (_startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideBulkActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Text('${_selectedRideIds.length} selected'),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.cancel, color: Colors.orange),
            label: const Text('Cancel All'),
            onPressed: () => _confirmBulkAction(
              'Cancel ${_selectedRideIds.length} rides?',
              _bulkCancelRides,
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete All'),
            onPressed: () => _confirmBulkAction(
              'Delete ${_selectedRideIds.length} rides?',
              _bulkDeleteRides,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _selectedRideIds.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList() {
    Query query = FirebaseFirestore.instance.collection('rides');

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    query = query.orderBy('timestamp', descending: true);
    query = query.limit(AdminConstants.itemsPerPage);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var rides = snapshot.data!.docs;

        if (_startDate != null && _endDate != null) {
          rides = rides.where((ride) {
            final data = ride.data() as Map<String, dynamic>;
            final ts = data['dateTime'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            return date.isAfter(_startDate!) && date.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          rides = rides.where((ride) {
            final data = ride.data() as Map<String, dynamic>;
            final from = (data['from'] ?? '').toString().toLowerCase();
            final to = (data['to'] ?? '').toString().toLowerCase();
            final name = (data['postedByName'] ?? '').toString().toLowerCase();
            return from.contains(_searchQuery) ||
                to.contains(_searchQuery) ||
                name.contains(_searchQuery);
          }).toList();
        }

        if (rides.isEmpty) {
          return _buildEmptyState('No rides found', Icons.directions_car_outlined);
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) => _buildRideCard(rides[index]),
          ),
        );
      },
    );
  }

  Widget _buildRideCard(DocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;
    final isSelected = _selectedRideIds.contains(ride.id);
    final ts = data['dateTime'] as Timestamp?;
    final dateTime = ts?.toDate();
    final formattedDate = dateTime != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(dateTime)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedRideIds.add(ride.id);
              } else {
                _selectedRideIds.remove(ride.id);
              }
            });
          },
        ),
        title: Text('${data['from']} → ${data['to']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 $formattedDate'),
            Text('👤 ${data['postedByName'] ?? 'Unknown'}'),
            Text('💺 ${data['seats']} seats | 💰 ₹${data['estimatedCost'] ?? 0}'),
            Text('Status: ${data['status'] ?? 'unknown'}',
                style: TextStyle(
                  color: _getStatusColor(data['status']),
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleRideAction(action, ride.id, data),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('👁️ View Details')),
            const PopupMenuItem(value: 'cancel', child: Text('❌ Cancel')),
            const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete')),
          ],
        ),
        onTap: () => _showRideDetails(ride.id, data),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // 👤 MANAGE USERS TAB
  Widget _buildManageUsersTab() {
    return Column(
      children: [
        _buildUserSearch(),
        if (_selectedUserIds.isNotEmpty) _buildUserBulkActions(),
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildUserSearch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: const InputDecoration(
          hintText: '🔍 Search users by name or email...',
          border: OutlineInputBorder(),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildUserBulkActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Text('${_selectedUserIds.length} selected'),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text('Ban All'),
            onPressed: () => _confirmBulkAction(
              'Ban ${_selectedUserIds.length} users?',
              _bulkBanUsers,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _selectedUserIds.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(AdminConstants.itemsPerPage)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var users = snapshot.data!.docs;

        if (_searchQuery.isNotEmpty) {
          users = users.where((user) {
            final data = user.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return _buildEmptyState('No users found', Icons.person_outline);
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) => _buildUserCard(users[index]),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final isSelected = _selectedUserIds.contains(user.id);
    final isBanned = data['isBanned'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedUserIds.add(user.id);
              } else {
                _selectedUserIds.remove(user.id);
              }
            });
          },
        ),
        title: Text(data['name'] ?? 'Unnamed User'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['email'] ?? 'No Email'),
            if (isBanned)
              const Text('🚫 BANNED',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleUserAction(action, user.id, data),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('👁️ View Profile')),
            PopupMenuItem(
              value: 'ban',
              child: Text(isBanned ? '✅ Unban' : '🚫 Ban'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete')),
          ],
        ),
        onTap: () => _showUserProfile(user.id, data),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  // ACTION HANDLERS
  void _handleRideAction(String action, String rideId, Map<String, dynamic> data) {
    switch (action) {
      case 'view':
        _showRideDetails(rideId, data);
        break;
      case 'cancel':
        _confirmAction('Cancel this ride?', () => _cancelRide(rideId));
        break;
      case 'delete':
        _confirmAction('Delete this ride?', () => _deleteRide(rideId));
        break;
    }
  }

  void _handleUserAction(String action, String userId, Map<String, dynamic> data) {
    switch (action) {
      case 'view':
        _showUserProfile(userId, data);
        break;
      case 'ban':
        final isBanned = data['isBanned'] ?? false;
        _confirmAction(
          isBanned ? 'Unban this user?' : 'Ban this user?',
              () => _toggleBanUser(userId, isBanned),
        );
        break;
      case 'delete':
        _confirmAction('Delete this user?', () => _deleteUser(userId));
        break;
    }
  }

  Future<void> _confirmAction(String message, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) onConfirm();
  }

  Future<void> _confirmBulkAction(String message, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Bulk Action'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) onConfirm();
  }

  Future<void> _deleteRide(String rideId) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
      await _logAdminAction('delete_ride', {'rideId': rideId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ride deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _cancelRide(String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .update({'status': 'cancelled'});
      await _logAdminAction('cancel_ride', {'rideId': rideId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ride cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _bulkDeleteRides() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var rideId in _selectedRideIds) {
        batch.delete(FirebaseFirestore.instance.collection('rides').doc(rideId));
      }
      await batch.commit();
      await _logAdminAction('bulk_delete_rides', {'count': _selectedRideIds.length});
      setState(() => _selectedRideIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Rides deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _bulkCancelRides() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var rideId in _selectedRideIds) {
        batch.update(
          FirebaseFirestore.instance.collection('rides').doc(rideId),
          {'status': 'cancelled'},
        );
      }
      await batch.commit();
      await _logAdminAction('bulk_cancel_rides', {'count': _selectedRideIds.length});
      setState(() => _selectedRideIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Rides cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleBanUser(String userId, bool isBanned) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isBanned': !isBanned});
      await _logAdminAction(isBanned ? 'unban_user' : 'ban_user', {'userId': userId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBanned ? '✅ User unbanned' : '🚫 User banned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      await _logAdminAction('delete_user', {'userId': userId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ User deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _bulkBanUsers() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var userId in _selectedUserIds) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(userId),
          {'isBanned': true},
        );
      }
      await batch.commit();
      await _logAdminAction('bulk_ban_users', {'count': _selectedUserIds.length});
      setState(() => _selectedUserIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Users banned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  void _showRideDetails(String rideId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final ts = data['dateTime'] as Timestamp?;
          final dateTime = ts?.toDate();

          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🚗 Ride Details',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildDetailRow('From', data['from'] ?? 'N/A'),
                _buildDetailRow('To', data['to'] ?? 'N/A'),
                _buildDetailRow('Date & Time',
                    dateTime != null ? DateFormat('MMM dd, yyyy hh:mm a').format(dateTime) : 'N/A'),
                _buildDetailRow('Posted By', data['postedByName'] ?? 'Unknown'),
                _buildDetailRow('Rider ID', data['riderId'] ?? 'N/A'),
                _buildDetailRow('Ride Type', data['rideType'] ?? 'N/A'),
                _buildDetailRow('Total Seats', data['seats']?.toString() ?? 'N/A'),
                _buildDetailRow('Remaining Seats', data['remainingSeats']?.toString() ?? 'N/A'),
                _buildDetailRow('Distance', '${data['distance_km']?.toStringAsFixed(2) ?? 'N/A'} km'),
                _buildDetailRow('Duration', '${data['duration_min']?.toStringAsFixed(0) ?? 'N/A'} min'),
                _buildDetailRow('Estimated Cost', '₹${data['estimatedCost'] ?? 0}'),
                _buildDetailRow('Status', data['status'] ?? 'unknown'),
                _buildDetailRow('Allow Multiple', data['allowMultiple'] == true ? 'Yes' : 'No'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Ride'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditRideDialog(rideId, data);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(String userId, Map<String, dynamic> data) {
    FirebaseFirestore.instance
        .collection('rides')
        .where('riderId', isEqualTo: userId)
        .get()
        .then((ridesSnapshot) {
      final userRides = ridesSnapshot.docs;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👤 User Profile',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow('Name', data['name'] ?? 'N/A'),
                  _buildDetailRow('Email', data['email'] ?? 'N/A'),
                  _buildDetailRow('User ID', userId),
                  _buildDetailRow('Status', data['isBanned'] == true ? '🚫 Banned' : '✅ Active'),
                  _buildDetailRow('Verified', data['verified'] == true ? '✅ Yes' : '❌ No'),
                  _buildDetailRow('Total Rides Posted', userRides.length.toString()),
                  const SizedBox(height: 24),
                  const Text('📊 Ride History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (userRides.isEmpty)
                    const Text('No rides posted yet',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...userRides.take(5).map((ride) {
                      final rideData = ride.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car),
                          title: Text('${rideData['from']} → ${rideData['to']}'),
                          subtitle: Text('Status: ${rideData['status']}'),
                          trailing: Text('₹${rideData['estimatedCost'] ?? 0}'),
                        ),
                      );
                    }).toList(),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  void _showEditRideDialog(String rideId, Map<String, dynamic> data) {
    final priceController = TextEditingController(
      text: data['estimatedCost']?.toString() ?? '0',
    );
    final seatsController = TextEditingController(
      text: data['seats']?.toString() ?? '1',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Edit Ride'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: seatsController,
              decoration: const InputDecoration(labelText: 'Total Seats'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('rides')
                    .doc(rideId)
                    .update({
                  'estimatedCost': int.tryParse(priceController.text) ?? 0,
                  'seats': int.tryParse(seatsController.text) ?? 1,
                });

                await _logAdminAction('edit_ride', {
                  'rideId': rideId,
                  'newPrice': priceController.text,
                  'newSeats': seatsController.text,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Ride updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportRides() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📊 Export feature coming soon')),
    );
  }

  void _exportUsers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📊 Export feature coming soon')),
    );
  }

  void _viewAuditLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuditLogsPage(),
      ),
    );
  }
}

class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📜 Audit Logs'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_logs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!.docs;

          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No audit logs yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              final timestamp = ts?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(data['action'] ?? 'Unknown Action'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin: ${data['adminEmail'] ?? 'Unknown'}'),
                      if (timestamp != null)
                        Text('Time: ${DateFormat('MMM dd, yyyy hh:mm a').format(timestamp)}'),
                      Text('Details: ${data['details']?.toString() ?? 'N/A'}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
