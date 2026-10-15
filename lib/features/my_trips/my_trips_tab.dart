import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';

/// My Trips tab — shows a user's ride history segmented by status.
///
/// Six tabs: Upcoming · Offered · Requested · Active · Completed · Cancelled
class MyTripsTab extends StatefulWidget {
  final String userId;
  const MyTripsTab({super.key, required this.userId});

  @override
  State<MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends State<MyTripsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabDefs = [
    _TabDef('Upcoming', Icons.schedule_rounded, ['pending', 'published']),
    _TabDef('Offered', Icons.add_road_rounded, null),
    _TabDef('Active', Icons.directions_car_rounded, ['in_progress']),
    _TabDef('Completed', Icons.check_circle_rounded, ['completed']),
    _TabDef('Cancelled', Icons.cancel_rounded, ['cancelled']),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabDefs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Your rides'),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Upcoming: rides driver posted that are not yet started
                _RideList(
                  userId: widget.userId,
                  isDriver: true,
                  statuses: const ['pending', 'published'],
                  emptyTitle: 'No upcoming rides',
                  emptySubtitle:
                      'Rides you offer will appear here before departure.',
                ),
                // Offered: all rides this user posted (any status)
                _RideList(
                  userId: widget.userId,
                  isDriver: true,
                  statuses: null,
                  emptyTitle: 'No offered rides',
                  emptySubtitle: 'Tap "Offer Ride" to post your first ride.',
                ),
                // Active
                _RideList(
                  userId: widget.userId,
                  isDriver: null, // both driver + passenger
                  statuses: const ['in_progress'],
                  emptyTitle: 'No active trips',
                  emptySubtitle: 'Active trips will appear here.',
                ),
                // Completed
                _RideList(
                  userId: widget.userId,
                  isDriver: null,
                  statuses: const ['completed'],
                  emptyTitle: 'No completed trips yet',
                  emptySubtitle: 'Rides you finish will be recorded here.',
                ),
                // Cancelled
                _RideList(
                  userId: widget.userId,
                  isDriver: null,
                  statuses: const ['cancelled'],
                  emptyTitle: 'No cancelled rides',
                  emptySubtitle: "Great — you haven't cancelled any rides!",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.navy,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.all(4),
          tabs: _tabDefs
              .map(
                (t) => Tab(
                  height: 38,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 14),
                      const SizedBox(width: 5),
                      Text(t.label),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ─── Tab definition ───────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final IconData icon;
  final List<String>? statuses;
  const _TabDef(this.label, this.icon, this.statuses);
}

// ─── Ride list ────────────────────────────────────────────────────────────────

class _RideList extends StatelessWidget {
  final String userId;
  final bool? isDriver; // null = both
  final List<String>? statuses;
  final String emptyTitle;
  final String emptySubtitle;

  const _RideList({
    required this.userId,
    required this.isDriver,
    required this.statuses,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  Query<Map<String, dynamic>> _buildQuery() {
    var q = FirebaseFirestore.instance
        .collection('rides')
        .orderBy('timestamp', descending: true)
        .limit(30);

    // Driver or passenger filter
    if (isDriver == true) {
      q = q.where('riderId', isEqualTo: userId);
    } else if (isDriver == false) {
      q = q.where('acceptedByList', arrayContains: userId);
    }
    // null = query all then filter in memory (both driver+passenger)

    if (statuses != null && statuses!.length == 1) {
      q = q.where('status', isEqualTo: statuses!.first);
    } else if (statuses != null && statuses!.isNotEmpty) {
      q = q.where('status', whereIn: statuses);
    }

    return q;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: RideCardSkeleton(),
          );
        }
        if (snapshot.hasError) {
          return PoolingEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Error loading trips',
            subtitle: snapshot.error.toString(),
          );
        }

        var docs = snapshot.data?.docs ?? [];

        // If isDriver == null we want both — filter in memory.
        if (isDriver == null) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final isRider = data['riderId'] == userId;
            final inList =
                ((data['acceptedByList'] as List?)?.contains(userId) ??
                    false) ||
                data['acceptedBy'] == userId;
            return isRider || inList;
          }).toList();
        }

        if (docs.isEmpty) {
          return PoolingEmptyState(
            icon: Icons.directions_car_outlined,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _TripCard(rideId: doc.id, data: data, userId: userId);
          },
        );
      },
    );
  }
}

// ─── Trip Card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> data;
  final String userId;

  const _TripCard({
    required this.rideId,
    required this.data,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final from = data['from'] as String? ?? 'Unknown';
    final to = data['to'] as String? ?? 'Unknown';
    final status = data['status'] as String? ?? 'pending';
    final ts = data['dateTime'] as dynamic;
    final DateTime? dateTime = ts != null
        ? (ts.runtimeType.toString().contains('Timestamp')
              ? (ts as dynamic).toDate() as DateTime
              : null)
        : null;
    final isDriver = data['riderId'] == userId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x07000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$from → $to',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isDriver
                    ? Icons.drive_eta_rounded
                    : Icons.person_outline_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                isDriver ? 'Driver' : 'Passenger',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (dateTime != null) ...[
                const Spacer(),
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(dateTime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      'pending' => (
        AppColors.navy,
        AppColors.yellow.withValues(alpha: 0.2),
        'Pending',
      ),
      'published' => (
        AppColors.navy,
        AppColors.yellow.withValues(alpha: 0.2),
        'Open',
      ),
      'in_progress' => (AppColors.success, const Color(0xFFDCFCE7), 'Active'),
      'completed' => (AppColors.info, const Color(0xFFDBEAFE), 'Done'),
      'cancelled' => (AppColors.error, const Color(0xFFFEE2E2), 'Cancelled'),
      _ => (AppColors.textSecondary, AppColors.surfaceDim, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
