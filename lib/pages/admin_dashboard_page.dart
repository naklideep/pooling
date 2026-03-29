import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'login_page.dart';

// ─── Brand Tokens ────────────────────────────────────────────────────────────
class GharTakColors {
  static const Color navy      = Color(0xFF1A2340);
  static const Color navyDeep  = Color(0xFF0F1826);
  static const Color yellow    = Color(0xFFFFCC00);
  static const Color background= Color(0xFFEEF0F5);
  static const Color card      = Colors.white;
  static const Color textLight = Colors.white;
  static const Color textMuted = Color(0xB3FFFFFF); // white 70%
}

// ─── Constants ────────────────────────────────────────────────────────────────
class AdminConstants {
  static const int itemsPerPage        = 20;
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const String adminRole        = 'admin';
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime? _startDate;
  DateTime? _endDate;
  String    _searchQuery  = '';
  String    _statusFilter = 'all';
  String    _rideSortBy   = 'newest';
  String    _userSortBy   = 'name_az';
  Timer?    _searchDebounce;

  Set<String> _selectedRideIds = {};
  Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }
    } catch (e) {
      _showSnack('Logout failed: $e', isError: true);
    }
  }

  Future<void> _logAdminAction(
      String action, Map<String, dynamic> details) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action'    : action,
        'adminId'   : user?.uid,
        'adminEmail': user?.email,
        'timestamp' : FieldValue.serverTimestamp(),
        'details'   : details,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd   = _endDate;

    await showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder           : (_) => _GharTakDateRangePicker(
        initialStart: tempStart,
        initialEnd  : tempEnd,
        onConfirm   : (start, end) {
          setState(() {
            _startDate = start;
            _endDate   = end;
          });
        },
      ),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AdminConstants.searchDebounce, () {
      setState(() => _searchQuery = query.toLowerCase());
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: GharTakColors.navy,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: GharTakColors.navy, fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: GharTakColors.yellow,
        behavior       : SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin         : const EdgeInsets.all(16),
        duration       : const Duration(seconds: 3),
      ),
    );
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharTakColors.background,
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    final topPad = MediaQuery.of(context).padding.top;
    return PreferredSize(
      preferredSize: Size.fromHeight(topPad + 112),
      child: Container(
        color: GharTakColors.navy,
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPad + 8, 8, 4),
              child: Row(
                children: [
                  // Logo pill
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color        : GharTakColors.yellow,
                      borderRadius : BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car_filled,
                        color: GharTakColors.navy, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'GharTak Admin',
                    style: TextStyle(
                      color     : Colors.white,
                      fontSize  : 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  _appBarIconBtn(Icons.refresh, () => setState(() {})),
                  PopupMenuButton<String>(
                    icon           : const Icon(Icons.more_vert, color: Colors.white),
                    color          : GharTakColors.navyDeep,
                    shape          : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (v) {
                      if (v == 'export_rides') _exportRides();
                      if (v == 'export_users') _exportUsers();
                      if (v == 'view_logs')    _viewAuditLogs();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'export_rides',
                        child: Text('📊  Export Rides',
                            style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 'export_users',
                        child: Text('👥  Export Users',
                            style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 'view_logs',
                        child: Text('📜  Audit Logs',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  _appBarIconBtn(Icons.logout, _logout),
                ],
              ),
            ),

            // ── Tab bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color        : GharTakColors.navyDeep,
                  borderRadius : BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller          : _tabController,
                  indicator: BoxDecoration(
                    color       : GharTakColors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize       : TabBarIndicatorSize.tab,
                  dividerColor        : Colors.transparent,
                  labelColor          : GharTakColors.navy,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  tabAlignment: TabAlignment.fill,
                  tabs: const [
                    Tab(height: 36, child: _TabLabel(Icons.bar_chart_rounded, 'Overview')),
                    Tab(height: 36, child: _TabLabel(Icons.directions_car_filled, 'Rides')),
                    Tab(height: 36, child: _TabLabel(Icons.people_alt_rounded, 'Users')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBarIconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon     : Icon(icon, color: Colors.white, size: 22),
      onPressed: onTap,
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').snapshots(),
      builder: (context, ridesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (!ridesSnap.hasData || !usersSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                    color: GharTakColors.yellow),
              );
            }

            final rides = ridesSnap.data!.docs;
            final users = usersSnap.data!.docs;

            final totalRides  = rides.length;
            final totalUsers  = users.length;
            final activeRides = rides
                .where((r) => (r.data() as Map)['status'] == 'pending')
                .length;
            final now = DateTime.now();
            final completedToday = rides.where((r) {
              final data = r.data() as Map;
              final ts   = data['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final d = ts.toDate();
              return data['status'] == 'completed' &&
                  d.year  == now.year  &&
                  d.month == now.month &&
                  d.day   == now.day;
            }).length;
            final carRides  = rides.where((r) => (r.data() as Map)['rideType'] == 'Car').length;
            final bikeRides = rides.where((r) => (r.data() as Map)['rideType'] == 'Bike').length;

            final totalRevenue = rides.fold<double>(0, (sum, r) {
              final data = r.data() as Map;
              return sum + ((data['estimatedCost'] as num?)?.toDouble() ?? 0);
            });

            final completedRides = rides
                .where((r) => (r.data() as Map)['status'] == 'completed')
                .length;
            final cancelledRides = rides
                .where((r) => (r.data() as Map)['status'] == 'cancelled')
                .length;

            return RefreshIndicator(
              color     : GharTakColors.yellow,
              onRefresh : () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // ── Stat grid ──────────────────────────────────────────
                  GridView.count(
                    shrinkWrap   : true,
                    physics      : const NeverScrollableScrollPhysics(),
                    crossAxisCount: _gridCols(context),
                    crossAxisSpacing: 12,
                    mainAxisSpacing : 12,
                    childAspectRatio: 1.1,
                    children: [
                      _statCard('Total Users',      totalUsers,      Icons.people_alt_rounded,    Colors.blue),
                      _statCard('Total Rides',      totalRides,      Icons.directions_car_filled, Colors.green),
                      _statCard('Active Rides',     activeRides,     Icons.pending_actions,       GharTakColors.yellow, dark: true),
                      _statCard('Done Today',       completedToday,  Icons.check_circle_rounded,  Colors.purple),
                      _statCard('Car Rides',        carRides,        Icons.directions_car,        Colors.teal),
                      _statCard('Bike Rides',       bikeRides,       Icons.two_wheeler,           Colors.indigo),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Quick stats card ───────────────────────────────────
                  _sectionCard(
                    title: '📈  Quick Stats',
                    child: Column(children: [
                      _statRow('Pending Rides',   activeRides.toString()),
                      _statRow('Completed Rides', completedRides.toString()),
                      _statRow('Cancelled Rides', cancelledRides.toString()),
                      _statRow(
                        'Avg. Cost',
                        rides.isEmpty
                            ? '₹0'
                            : '₹${(totalRevenue / totalRides).toStringAsFixed(2)}',
                      ),
                    ]),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(String title, int count, IconData icon, Color accent,
      {bool dark = false}) {
    final bg   = dark ? GharTakColors.yellow : GharTakColors.navy;
    final fg   = dark ? GharTakColors.navy   : Colors.white;
    final sub  = dark ? GharTakColors.navyDeep.withOpacity(0.6) : Colors.white54;

    return Container(
      decoration: BoxDecoration(
        color       : bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow   : [
          BoxShadow(
            color  : bg.withOpacity(0.35),
            blurRadius  : 12,
            offset      : const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment : MainAxisAlignment.start,
        mainAxisSize      : MainAxisSize.min,
        children: [
          Container(
            padding     : const EdgeInsets.all(8),
            decoration  : BoxDecoration(
              color       : fg.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: dark ? GharTakColors.navy : accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            count.toString(),
            style: TextStyle(
              color     : fg,
              fontSize  : 26,
              fontWeight: FontWeight.bold,
              height    : 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15, color: GharTakColors.navy)),
          Container(
            padding     : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration  : BoxDecoration(
              color       : GharTakColors.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(value,
                style: const TextStyle(
                    fontSize  : 14,
                    fontWeight: FontWeight.bold,
                    color     : GharTakColors.navy)),
          ),
        ],
      ),
    );
  }

  int _gridCols(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > 1200) return 4;
    if (w > 800)  return 3;
    return 2;
  }

  // ── Rides Tab ─────────────────────────────────────────────────────────────

  Widget _buildManageRidesTab() {
    return Column(children: [
      _buildRideFilters(),
      if (_selectedRideIds.isNotEmpty) _buildRideBulkActions(),
      Expanded(child: _buildRidesList()),
    ]);
  }

  Widget _buildRideFilters() {
    return Container(
      margin : const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow   : [
          BoxShadow(
              color: GharTakColors.navy.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // Search field
        TextField(
          onChanged  : _onSearchChanged,
          style      : const TextStyle(color: GharTakColors.navy),
          decoration : InputDecoration(
            hintText    : 'Search by location or name…',
            hintStyle   : const TextStyle(color: Colors.black38),
            prefixIcon  : const Icon(Icons.search, color: GharTakColors.navy),
            filled      : true,
            fillColor   : GharTakColors.background,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  : BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sort chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _sortChip('Newest',  'newest',    _rideSortBy, (v) => setState(() => _rideSortBy = v)),
            _sortChip('Oldest',  'oldest',    _rideSortBy, (v) => setState(() => _rideSortBy = v)),
            _sortChip('Cost ↓',  'cost_asc',  _rideSortBy, (v) => setState(() => _rideSortBy = v)),
            _sortChip('Cost ↑',  'cost_desc', _rideSortBy, (v) => setState(() => _rideSortBy = v)),
            _sortChip('Seats',   'seats',     _rideSortBy, (v) => setState(() => _rideSortBy = v)),
          ]),
        ),
        const SizedBox(height: 10),

        // Status + Date row
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                width: 180,
                padding     : const EdgeInsets.symmetric(horizontal: 12),
                decoration  : BoxDecoration(
                  color       : GharTakColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value   : _statusFilter,
                    isExpanded: true,
                    style   : const TextStyle(
                        color: GharTakColors.navy, fontWeight: FontWeight.w600),
                    dropdownColor: Colors.white,
                    icon    : const Icon(Icons.expand_more, color: GharTakColors.navy),
                    onChanged: (v) => setState(() => _statusFilter = v!),
                    items   : const [
                      DropdownMenuItem(value: 'all',       child: Text('All Status')),
                      DropdownMenuItem(value: 'pending',   child: Text('Pending')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickDateRange(context),
                child: Container(
                  padding     : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration  : BoxDecoration(
                    color       : _startDate != null
                        ? GharTakColors.yellow
                        : GharTakColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.date_range,
                        size : 18,
                        color: _startDate != null
                            ? GharTakColors.navy
                            : Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      _startDate == null
                          ? 'Date Range'
                          : '${DateFormat('MM/dd').format(_startDate!)} – ${DateFormat('MM/dd').format(_endDate!)}',
                      style: TextStyle(
                        color     : _startDate != null ? GharTakColors.navy : Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize  : 13,
                      ),
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() {
                          _startDate = null;
                          _endDate   = null;
                        }),
                        child: const Icon(Icons.close,
                            size: 16, color: GharTakColors.navy),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
      ]),
    );
  }

  Widget _buildRideBulkActions() {
    return _bulkBar(
      label   : '${_selectedRideIds.length} rides selected',
      actions : [
        _bulkBtn('Cancel All', Icons.cancel_outlined, Colors.orange,
                () => _confirmBulkAction(
                'Cancel ${_selectedRideIds.length} rides?', _bulkCancelRides)),
        _bulkBtn('Delete All', Icons.delete_outline, Colors.redAccent,
                () => _confirmBulkAction(
                'Delete ${_selectedRideIds.length} rides?', _bulkDeleteRides)),
      ],
      onClear : () => setState(() => _selectedRideIds.clear()),
    );
  }

  Widget _buildRidesList() {
    Query query = FirebaseFirestore.instance.collection('rides');
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    query = query.orderBy('timestamp', descending: true).limit(AdminConstants.itemsPerPage);

    return StreamBuilder<QuerySnapshot>(
      stream : query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: GharTakColors.yellow));
        }

        var rides = snapshot.data!.docs;

        if (_startDate != null && _endDate != null) {
          rides = rides.where((r) {
            final data = r.data() as Map<String, dynamic>;
            final ts   = data['dateTime'] as Timestamp?;
            if (ts == null) return false;
            final d = ts.toDate();
            return d.isAfter(_startDate!) &&
                d.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          rides = rides.where((r) {
            final data = r.data() as Map<String, dynamic>;
            final from = (data['from'] ?? '').toString().toLowerCase();
            final to   = (data['to']   ?? '').toString().toLowerCase();
            final name = (data['postedByName'] ?? '').toString().toLowerCase();
            return from.contains(_searchQuery) ||
                to.contains(_searchQuery) ||
                name.contains(_searchQuery);
          }).toList();
        }

        // ── Client-side sort ──────────────────────────────────────────
        rides.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          switch (_rideSortBy) {
            case 'oldest':
              final at = (ad['dateTime'] as Timestamp?)?.seconds ?? 0;
              final bt = (bd['dateTime'] as Timestamp?)?.seconds ?? 0;
              return at.compareTo(bt);
            case 'cost_asc':
              final ac = (ad['estimatedCost'] as num?)?.toDouble() ?? 0;
              final bc = (bd['estimatedCost'] as num?)?.toDouble() ?? 0;
              return ac.compareTo(bc);
            case 'cost_desc':
              final ac = (ad['estimatedCost'] as num?)?.toDouble() ?? 0;
              final bc = (bd['estimatedCost'] as num?)?.toDouble() ?? 0;
              return bc.compareTo(ac);
            case 'seats':
              final as_ = (ad['seats'] as num?)?.toInt() ?? 0;
              final bs  = (bd['seats'] as num?)?.toInt() ?? 0;
              return bs.compareTo(as_);
            default: // newest
              final at = (ad['dateTime'] as Timestamp?)?.seconds ?? 0;
              final bt = (bd['dateTime'] as Timestamp?)?.seconds ?? 0;
              return bt.compareTo(at);
          }
        });

        if (rides.isEmpty) {
          return _emptyState('No rides found', Icons.directions_car_outlined);
        }

        return RefreshIndicator(
          color    : GharTakColors.yellow,
          onRefresh: () async => setState(() {}),
          child    : ListView.builder(
            padding    : const EdgeInsets.only(bottom: 24),
            itemCount  : rides.length,
            itemBuilder: (context, i) => _rideCard(rides[i]),
          ),
        );
      },
    );
  }

  Widget _rideCard(DocumentSnapshot ride) {
    final data       = ride.data() as Map<String, dynamic>;
    final isSelected = _selectedRideIds.contains(ride.id);
    final ts         = data['dateTime'] as Timestamp?;
    final formatted  = ts != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(ts.toDate())
        : 'N/A';
    final status = data['status'] as String? ?? 'unknown';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color       : isSelected ? GharTakColors.yellow.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : Border.all(
          color: isSelected ? GharTakColors.yellow : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color     : GharTakColors.navy.withOpacity(0.06),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRideDetails(ride.id, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              Checkbox(
                value      : isSelected,
                activeColor: GharTakColors.yellow,
                checkColor : GharTakColors.navy,
                shape      : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged  : (v) => setState(() => v == true
                    ? _selectedRideIds.add(ride.id)
                    : _selectedRideIds.remove(ride.id)),
              ),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['from']}  →  ${data['to']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color     : GharTakColors.navy,
                          fontSize  : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(formatted,
                        style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    const SizedBox(height: 2),
                    Text('👤 ${data['postedByName'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing    : 8,
                      runSpacing : 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('💺 ${data['seats']} seats',
                            style: const TextStyle(fontSize: 11)),
                        Text('₹${data['estimatedCost'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: GharTakColors.navy)),
                        _statusChip(status),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon       : const Icon(Icons.more_vert, color: GharTakColors.navy),
                color      : GharTakColors.navyDeep,
                shape      : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected : (a) => _handleRideAction(a, ride.id, data),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'view',
                      child: Text('👁️  Details', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'cancel',
                      child: Text('❌  Cancel',  style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'delete',
                      child: Text('🗑️  Delete',  style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    switch (status) {
      case 'pending':
        bg = GharTakColors.yellow; fg = GharTakColors.navy;
        break;
      case 'completed':
        bg = const Color(0xFF4CAF50); fg = Colors.white;
        break;
      case 'cancelled':
        bg = const Color(0xFFE53935); fg = Colors.white;
        break;
      default:
        bg = Colors.grey.shade200; fg = Colors.black54;
    }
    return Container(
      padding     : const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration  : BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── Users Tab ─────────────────────────────────────────────────────────────

  Widget _buildManageUsersTab() {
    return Column(children: [
      _buildUserSearch(),
      if (_selectedUserIds.isNotEmpty) _buildUserBulkActions(),
      Expanded(child: _buildUsersList()),
    ]);
  }

  Widget _buildUserSearch() {
    return Container(
      margin : const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow   : [
          BoxShadow(
              color: GharTakColors.navy.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        TextField(
          onChanged  : _onSearchChanged,
          style      : const TextStyle(color: GharTakColors.navy),
          decoration : InputDecoration(
            hintText   : 'Search users by name or email…',
            hintStyle  : const TextStyle(color: Colors.black38),
            prefixIcon : const Icon(Icons.search, color: GharTakColors.navy),
            filled     : true,
            fillColor  : GharTakColors.background,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  : BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _sortChip('Name A→Z',     'name_az',      _userSortBy, (v) => setState(() => _userSortBy = v)),
            _sortChip('Name Z→A',     'name_za',      _userSortBy, (v) => setState(() => _userSortBy = v)),
            _sortChip('Banned First', 'banned_first', _userSortBy, (v) => setState(() => _userSortBy = v)),
            _sortChip('Active First', 'active_first', _userSortBy, (v) => setState(() => _userSortBy = v)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildUserBulkActions() {
    return _bulkBar(
      label  : '${_selectedUserIds.length} users selected',
      actions: [
        _bulkBtn('Ban All', Icons.block, Colors.redAccent,
                () => _confirmBulkAction(
                'Ban ${_selectedUserIds.length} users?', _bulkBanUsers)),
      ],
      onClear: () => setState(() => _selectedUserIds.clear()),
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
          return const Center(
              child: CircularProgressIndicator(color: GharTakColors.yellow));
        }

        var users = snapshot.data!.docs;

        if (_searchQuery.isNotEmpty) {
          users = users.where((u) {
            final data  = u.data() as Map<String, dynamic>;
            final name  = (data['name']  ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        // ── Client-side sort ──────────────────────────────────────────
        users.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          switch (_userSortBy) {
            case 'name_za':
              return (bd['name'] ?? '').toString()
                  .compareTo((ad['name'] ?? '').toString());
            case 'banned_first':
              final ab = (ad['isBanned'] ?? false) ? 0 : 1;
              final bb = (bd['isBanned'] ?? false) ? 0 : 1;
              return ab.compareTo(bb);
            case 'active_first':
              final ab = (ad['isBanned'] ?? false) ? 1 : 0;
              final bb = (bd['isBanned'] ?? false) ? 1 : 0;
              return ab.compareTo(bb);
            default: // name_az
              return (ad['name'] ?? '').toString()
                  .compareTo((bd['name'] ?? '').toString());
          }
        });

        if (users.isEmpty) {
          return _emptyState('No users found', Icons.person_outline);
        }

        return RefreshIndicator(
          color    : GharTakColors.yellow,
          onRefresh: () async => setState(() {}),
          child    : ListView.builder(
            padding    : const EdgeInsets.only(bottom: 24),
            itemCount  : users.length,
            itemBuilder: (context, i) => _userCard(users[i]),
          ),
        );
      },
    );
  }

  Widget _userCard(DocumentSnapshot user) {
    final data       = user.data() as Map<String, dynamic>;
    final isSelected = _selectedUserIds.contains(user.id);
    final isBanned   = data['isBanned'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color       : isSelected ? GharTakColors.yellow.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : Border.all(
          color: isSelected ? GharTakColors.yellow : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color     : GharTakColors.navy.withOpacity(0.06),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUserProfile(user.id, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              Checkbox(
                value      : isSelected,
                activeColor: GharTakColors.yellow,
                checkColor : GharTakColors.navy,
                shape      : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged  : (v) => setState(() => v == true
                    ? _selectedUserIds.add(user.id)
                    : _selectedUserIds.remove(user.id)),
              ),
              // Avatar
              Container(
                width : 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isBanned
                      ? const Color(0xFFE53935).withOpacity(0.1)
                      : GharTakColors.navy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: isBanned ? Colors.red : GharTakColors.navy,
                  size : 20,
                ),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Unnamed User',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color     : GharTakColors.navy,
                          fontSize  : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['email'] ?? 'No Email',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isBanned) ...[
                      const SizedBox(height: 4),
                      _statusChip('banned'),
                    ],
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon       : const Icon(Icons.more_vert, color: GharTakColors.navy),
                color      : GharTakColors.navyDeep,
                shape      : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected : (a) => _handleUserAction(a, user.id, data),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'view',
                      child: Text('👁️  Profile', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                    value: 'ban',
                    child: Text(isBanned ? '✅  Unban' : '🚫  Ban',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('🗑️  Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  // ── Sort dropdown (reusable) ──────────────────────────────────────────────

  Widget _sortChip(String label, String value, String current, ValueChanged<String> onTap) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? GharTakColors.yellow : GharTakColors.navy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [
            BoxShadow(
              color: GharTakColors.yellow.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color     : isActive ? GharTakColors.navy : Colors.white,
            fontSize  : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sortDropdown<T>({
    required T value,
    required IconData icon,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding    : const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration : BoxDecoration(
        color      : GharTakColors.navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GharTakColors.yellow, size: 16),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value        : value,
              isDense      : true,
              dropdownColor: GharTakColors.navyDeep,
              iconSize     : 18,
              icon: const Icon(Icons.expand_more, color: GharTakColors.yellow),
              style: const TextStyle(
                color     : Colors.white,
                fontSize  : 13,
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
              items: items.entries
                  .map((e) => DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value,
                    style: const TextStyle(
                        color    : Colors.white,
                        fontSize : 13)),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width      : double.infinity,
      padding    : const EdgeInsets.all(18),
      decoration : BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow   : [
          BoxShadow(
              color: GharTakColors.navy.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize  : 17,
                  fontWeight: FontWeight.bold,
                  color     : GharTakColors.navy)),
          Divider(
              height: 24,
              color : GharTakColors.navy.withOpacity(0.1)),
          child,
        ],
      ),
    );
  }

  Widget _bulkBar({
    required String label,
    required List<Widget> actions,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color  : GharTakColors.yellow,
      child  : Row(children: [
        Text(label,
            style: const TextStyle(
                color     : GharTakColors.navy,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        ...actions,
        IconButton(
          icon     : const Icon(Icons.clear, color: GharTakColors.navy),
          onPressed: onClear,
        ),
      ]),
    );
  }

  Widget _bulkBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton.icon(
      icon : Icon(icon, color: color, size: 18),
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding    : const EdgeInsets.all(24),
            decoration : BoxDecoration(
              color      : GharTakColors.navy.withOpacity(0.06),
              shape      : BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: GharTakColors.navy.withOpacity(0.3)),
          ),
          const SizedBox(height: 16),
          Text(msg,
              style: TextStyle(
                  fontSize: 16,
                  color   : GharTakColors.navy.withOpacity(0.4),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color     : GharTakColors.navy,
                    fontSize  : 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  void _handleRideAction(String action, String rideId, Map<String, dynamic> data) {
    switch (action) {
      case 'view':   _showRideDetails(rideId, data); break;
      case 'cancel': _confirmAction('Cancel this ride?', () => _cancelRide(rideId)); break;
      case 'delete': _confirmAction('Delete this ride?', () => _deleteRide(rideId)); break;
    }
  }

  void _handleUserAction(String action, String userId, Map<String, dynamic> data) {
    switch (action) {
      case 'view': _showUserProfile(userId, data); break;
      case 'ban':
        final isBanned = data['isBanned'] ?? false;
        _confirmAction(
          isBanned ? 'Unban this user?' : 'Ban this user?',
              () => _toggleBanUser(userId, isBanned),
        );
        break;
      case 'delete': _confirmAction('Delete this user?', () => _deleteUser(userId)); break;
    }
  }

  Future<void> _confirmAction(String message, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _themedDialog(message, 'Confirm'),
    );
    if (result == true) onConfirm();
  }

  Future<void> _confirmBulkAction(String message, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _themedDialog(message, '⚠️  Bulk Action'),
    );
    if (result == true) onConfirm();
  }

  Widget _themedDialog(String message, String title) {
    return AlertDialog(
      backgroundColor: GharTakColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text(message,
          style: const TextStyle(color: GharTakColors.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child    : const Text('Cancel',
              style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style    : ElevatedButton.styleFrom(
            backgroundColor: GharTakColors.yellow,
            foregroundColor: GharTakColors.navy,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Confirm',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Firestore actions ─────────────────────────────────────────────────────

  Future<void> _deleteRide(String rideId) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
      await _logAdminAction('delete_ride', {'rideId': rideId});
      _showSnack('Ride deleted');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _cancelRide(String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .update({'status': 'cancelled'});
      await _logAdminAction('cancel_ride', {'rideId': rideId});
      _showSnack('Ride cancelled');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _bulkDeleteRides() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedRideIds) {
        batch.delete(FirebaseFirestore.instance.collection('rides').doc(id));
      }
      await batch.commit();
      await _logAdminAction('bulk_delete_rides', {'count': _selectedRideIds.length});
      setState(() => _selectedRideIds.clear());
      _showSnack('Rides deleted');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _bulkCancelRides() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedRideIds) {
        batch.update(
          FirebaseFirestore.instance.collection('rides').doc(id),
          {'status': 'cancelled'},
        );
      }
      await batch.commit();
      await _logAdminAction('bulk_cancel_rides', {'count': _selectedRideIds.length});
      setState(() => _selectedRideIds.clear());
      _showSnack('Rides cancelled');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _toggleBanUser(String userId, bool isBanned) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isBanned': !isBanned});
      await _logAdminAction(
          isBanned ? 'unban_user' : 'ban_user', {'userId': userId});
      _showSnack(isBanned ? 'User unbanned' : 'User banned');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      await _logAdminAction('delete_user', {'userId': userId});
      _showSnack('User deleted');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _bulkBanUsers() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedUserIds) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(id),
          {'isBanned': true},
        );
      }
      await batch.commit();
      await _logAdminAction('bulk_ban_users', {'count': _selectedUserIds.length});
      setState(() => _selectedUserIds.clear());
      _showSnack('Users banned');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  // ── Detail sheets ─────────────────────────────────────────────────────────

  void _showRideDetails(String rideId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context        : context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder        : (_) => _themedSheet(
        title  : '🚗  Ride Details',
        content: [
          _buildDetailRow('From',        data['from']             ?? 'N/A'),
          _buildDetailRow('To',          data['to']               ?? 'N/A'),
          _buildDetailRow('Date & Time', _fmtTimestamp(data['dateTime'])),
          _buildDetailRow('Posted By',   data['postedByName']     ?? 'Unknown'),
          _buildDetailRow('Rider ID',    data['riderId']          ?? 'N/A'),
          _buildDetailRow('Ride Type',   data['rideType']         ?? 'N/A'),
          _buildDetailRow('Total Seats', data['seats']?.toString() ?? 'N/A'),
          _buildDetailRow('Remaining',   data['remainingSeats']?.toString() ?? 'N/A'),
          _buildDetailRow('Distance',    '${data['distance_km']?.toStringAsFixed(2) ?? 'N/A'} km'),
          _buildDetailRow('Duration',    '${data['duration_min']?.toStringAsFixed(0) ?? 'N/A'} min'),
          _buildDetailRow('Cost',        '₹${data['estimatedCost'] ?? 0}'),
          _buildDetailRow('Status',      data['status']           ?? 'unknown'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon : const Icon(Icons.edit_outlined),
              label: const Text('Edit Ride',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: GharTakColors.yellow,
                foregroundColor: GharTakColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showEditRideDialog(rideId, data);
              },
            ),
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
        .then((snap) {
      final userRides = snap.docs;
      showModalBottomSheet(
        context           : context,
        isScrollControlled: true,
        backgroundColor   : Colors.transparent,
        builder           : (_) => _themedSheet(
          title  : '👤  User Profile',
          content: [
            _buildDetailRow('Name',          data['name']   ?? 'N/A'),
            _buildDetailRow('Email',         data['email']  ?? 'N/A'),
            _buildDetailRow('User ID',       userId),
            _buildDetailRow('Status',
                data['isBanned'] == true ? '🚫 Banned' : '✅ Active'),
            _buildDetailRow('Verified',
                data['verified'] == true ? '✅ Yes' : '❌ No'),
            _buildDetailRow('Rides Posted',  userRides.length.toString()),
            const SizedBox(height: 16),
            const Text('📊  Ride History',
                style: TextStyle(
                    fontSize  : 16,
                    fontWeight: FontWeight.bold,
                    color     : GharTakColors.navy)),
            const SizedBox(height: 10),
            if (userRides.isEmpty)
              const Text('No rides posted yet',
                  style: TextStyle(color: Colors.black45))
            else
              ...userRides.take(5).map((r) {
                final rd = r.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color       : GharTakColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.directions_car,
                        color: GharTakColors.navy, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${rd['from']} → ${rd['to']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color     : GharTakColors.navy)),
                    ),
                    _statusChip(rd['status'] ?? 'unknown'),
                  ]),
                );
              }),
          ],
        ),
      );
    });
  }

  Widget _themedSheet({required String title, required List<Widget> content}) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize    : 0.95,
      minChildSize    : 0.5,
      expand          : false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin : const EdgeInsets.only(top: 12),
            width  : 40,
            height : 4,
            decoration: BoxDecoration(
              color       : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color       : GharTakColors.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon     : const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding   : const EdgeInsets.all(20),
              children  : content,
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(ts.toDate());
    }
    return 'N/A';
  }

  void _showEditRideDialog(String rideId, Map<String, dynamic> data) {
    final priceCtrl = TextEditingController(
        text: data['estimatedCost']?.toString() ?? '0');
    final seatsCtrl = TextEditingController(
        text: data['seats']?.toString() ?? '1');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GharTakColors.navy,
        shape          : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('✏️  Edit Ride',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(priceCtrl, 'Price (₹)', TextInputType.number),
          const SizedBox(height: 12),
          _dialogField(seatsCtrl, 'Total Seats', TextInputType.number),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child    : const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style    : ElevatedButton.styleFrom(
              backgroundColor: GharTakColors.yellow,
              foregroundColor: GharTakColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('rides')
                    .doc(rideId)
                    .update({
                  'estimatedCost': int.tryParse(priceCtrl.text) ?? 0,
                  'seats'        : int.tryParse(seatsCtrl.text) ?? 1,
                });
                await _logAdminAction('edit_ride', {
                  'rideId'  : rideId,
                  'newPrice': priceCtrl.text,
                  'newSeats': seatsCtrl.text,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _showSnack('Ride updated');
                }
              } catch (e) {
                _showSnack('Error: $e', isError: true);
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
      TextEditingController ctrl, String label, TextInputType type) {
    return TextField(
      controller    : ctrl,
      keyboardType  : type,
      style         : const TextStyle(color: Colors.white),
      decoration    : InputDecoration(
        labelText   : label,
        labelStyle  : const TextStyle(color: Colors.white60),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: GharTakColors.yellow),
        ),
      ),
    );
  }

  // ── Export / Logs (stubs) ──────────────────────────────────────────────────

  void _exportRides() => _showSnack('Export feature coming soon');
  void _exportUsers() => _showSnack('Export feature coming soon');

  void _viewAuditLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuditLogsPage()),
    );
  }
}

// ─── Custom Date Range Picker ─────────────────────────────────────────────────

class _GharTakDateRangePicker extends StatefulWidget {
  final DateTime?                          initialStart;
  final DateTime?                          initialEnd;
  final void Function(DateTime, DateTime) onConfirm;

  const _GharTakDateRangePicker({
    required this.initialStart,
    required this.initialEnd,
    required this.onConfirm,
  });

  @override
  State<_GharTakDateRangePicker> createState() =>
      _GharTakDateRangePickerState();
}

class _GharTakDateRangePickerState extends State<_GharTakDateRangePicker> {
  late DateTime _focusedMonth;
  DateTime?     _start;
  DateTime?     _end;

  static const List<String> _weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  static const List<String> _months   = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  void initState() {
    super.initState();
    _start        = widget.initialStart;
    _end          = widget.initialEnd;
    _focusedMonth = DateTime(
      (_start ?? DateTime.now()).year,
      (_start ?? DateTime.now()).month,
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
  });

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // fresh start
        _start = day;
        _end   = null;
      } else {
        // picking end
        if (day.isBefore(_start!)) {
          _end   = _start;
          _start = day;
        } else if (_isSameDay(day, _start!)) {
          // single day = same start & end
          _end = day;
        } else {
          _end = day;
        }
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  bool _isStart(DateTime day) => _start != null && _isSameDay(day, _start!);
  bool _isEnd  (DateTime day) => _end   != null && _isSameDay(day, _end!);

  List<DateTime?> _buildDays() {
    final first    = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final last     = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final leadBlanks = first.weekday % 7; // Sunday = 0
    final days     = <DateTime?>[];
    for (var i = 0; i < leadBlanks; i++) days.add(null);
    for (var d = 1; d <= last.day; d++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    return days;
  }

  String _formatSelected() {
    if (_start == null) return 'Select start date';
    final fmt = DateFormat('MMM dd, yyyy');
    if (_end == null)   return '${fmt.format(_start!)}  →  ?';
    return '${fmt.format(_start!)}  →  ${fmt.format(_end!)}';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final days  = _buildDays();
    final today = DateTime.now();
    final canConfirm = _start != null && _end != null;

    return Container(
      decoration: const BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── drag handle ─────────────────────────────────────────────
          Container(
            margin : const EdgeInsets.only(top: 10, bottom: 4),
            width  : 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4)),
          ),

          // ── header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: const BoxDecoration(
              color       : GharTakColors.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding    : const EdgeInsets.all(6),
                    decoration : BoxDecoration(
                      color      : GharTakColors.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.date_range,
                        color: GharTakColors.navy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Select Date Range',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize  : 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon     : const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 12),
                // Selected range pill
                Container(
                  width  : double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color       : const Color(0xFF253055),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatSelected(),
                    style: TextStyle(
                      color     : _start == null
                          ? Colors.white38
                          : GharTakColors.yellow,
                      fontSize  : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── calendar body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(children: [

              // month nav
              Row(children: [
                _navBtn(Icons.chevron_left, _prevMonth),
                Expanded(
                  child: Text(
                    '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color     : GharTakColors.navy,
                        fontSize  : 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                _navBtn(Icons.chevron_right, _nextMonth),
              ]),
              const SizedBox(height: 12),

              // weekday headers
              Row(
                children: _weekDays.map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize  : 12,
                            fontWeight: FontWeight.bold,
                            color     : GharTakColors.navy)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 6),

              // days grid
              GridView.count(
                crossAxisCount : 7,
                shrinkWrap     : true,
                physics        : const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.1,
                children: days.map((day) {
                  if (day == null) return const SizedBox();

                  final isToday  = _isSameDay(day, today);
                  final isStart  = _isStart(day);
                  final isEnd    = _isEnd(day);
                  final inRange  = _isInRange(day);
                  final selected = isStart || isEnd;

                  return GestureDetector(
                    onTap: () => _onDayTap(day),
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: selected
                            ? GharTakColors.yellow
                            : inRange
                            ? GharTakColors.yellow.withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.only(
                          topLeft    : Radius.circular(
                              isStart || (!inRange && !isEnd) ? 10 : 0),
                          bottomLeft : Radius.circular(
                              isStart || (!inRange && !isEnd) ? 10 : 0),
                          topRight   : Radius.circular(
                              isEnd   || (!inRange && !isStart) ? 10 : 0),
                          bottomRight: Radius.circular(
                              isEnd   || (!inRange && !isStart) ? 10 : 0),
                        ),
                        border: isToday && !selected
                            ? Border.all(
                            color: GharTakColors.navy, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize  : 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected
                                ? GharTakColors.navy
                                : inRange
                                ? GharTakColors.navy
                                : isToday
                                ? GharTakColors.navy
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),

          // ── quick presets ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _preset('Today',       today, today),
                _preset('Last 7 days', today.subtract(const Duration(days: 6)), today),
                _preset('Last 30 days',today.subtract(const Duration(days: 29)), today),
                _preset('This month',
                    DateTime(today.year, today.month, 1),
                    DateTime(today.year, today.month + 1, 0)),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── action buttons ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(children: [
              // Clear
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() { _start = null; _end = null; });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GharTakColors.navy,
                    side: const BorderSide(color: GharTakColors.navy, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Clear',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              // Apply
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: canConfirm
                      ? () {
                    Navigator.pop(context);
                    widget.onConfirm(_start!, _end!);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canConfirm
                        ? GharTakColors.yellow
                        : Colors.grey.shade200,
                    foregroundColor: GharTakColors.navy,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey,
                    elevation: canConfirm ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply Range',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding    : const EdgeInsets.all(8),
        decoration : BoxDecoration(
          color      : GharTakColors.navy.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: GharTakColors.navy, size: 20),
      ),
    );
  }

  Widget _preset(String label, DateTime start, DateTime end) {
    final isActive = _start != null && _end != null &&
        _isSameDay(_start!, start) && _isSameDay(_end!, end);
    return GestureDetector(
      onTap: () => setState(() {
        _start = start;
        _end   = end;
        _focusedMonth = DateTime(start.year, start.month);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin  : const EdgeInsets.only(right: 8),
        padding : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color       : isActive ? GharTakColors.yellow : GharTakColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color     : isActive ? GharTakColors.navy : Colors.white,
                fontSize  : 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Tab label helper ─────────────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _TabLabel(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

// ─── Audit Logs Page ──────────────────────────────────────────────────────────

class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharTakColors.background,
      appBar: AppBar(
        backgroundColor : GharTakColors.navy,
        foregroundColor : Colors.white,
        elevation       : 0,
        title: Row(children: [
          Container(
            padding    : const EdgeInsets.all(6),
            decoration : BoxDecoration(
              color      : GharTakColors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history,
                color: GharTakColors.navy, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Audit Logs',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream : FirebaseFirestore.instance
            .collection('admin_logs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: GharTakColors.yellow));
          }

          final logs = snapshot.data!.docs;

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding    : const EdgeInsets.all(24),
                    decoration : BoxDecoration(
                      color      : GharTakColors.navy.withOpacity(0.06),
                      shape      : BoxShape.circle,
                    ),
                    child: Icon(Icons.history,
                        size : 56,
                        color: GharTakColors.navy.withOpacity(0.3)),
                  ),
                  const SizedBox(height: 16),
                  Text('No audit logs yet',
                      style: TextStyle(
                          fontSize  : 16,
                          color     : GharTakColors.navy.withOpacity(0.4),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding    : const EdgeInsets.all(12),
            itemCount  : logs.length,
            itemBuilder: (context, i) {
              final data = logs[i].data() as Map<String, dynamic>;
              final ts   = data['timestamp'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color       : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow   : [
                    BoxShadow(
                        color: GharTakColors.navy.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding    : const EdgeInsets.all(8),
                      decoration : BoxDecoration(
                        color      : GharTakColors.yellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history,
                          color: GharTakColors.navy, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['action'] ?? 'Unknown',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color     : GharTakColors.navy,
                                  fontSize  : 14)),
                          const SizedBox(height: 2),
                          Text(data['adminEmail'] ?? 'Unknown admin',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          if (ts != null)
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a')
                                  .format(ts.toDate()),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38),
                            ),
                          if (data['details'] != null)
                            Text(data['details'].toString(),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}