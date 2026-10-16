import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/ride_card.dart';
import '../../core/widgets/loading_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Find Ride tab — search and discover available rides.
///
/// Wraps the existing FindRideWidget functionality with the
/// new navigation shell and design system.
class FindRideTab extends StatefulWidget {
  final String userId;
  const FindRideTab({super.key, required this.userId});

  @override
  State<FindRideTab> createState() => _FindRideTabState();
}

class _FindRideTabState extends State<FindRideTab> {
  final _searchCtrl = TextEditingController();
  String _searchQ = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Find your next ride'),
          _buildSearchBar(),
          Expanded(child: _buildRideList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
            hintText: 'Search destination or driver…',
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _searchQ.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQ = '');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRideList() {
    final query = FirebaseFirestore.instance
        .collection('rides')
        .where('status', whereIn: ['pending', 'published'])
        .orderBy('timestamp', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: RideCardSkeleton(),
          );
        }
        if (snapshot.hasError) {
          return PoolingEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: 'Unable to load rides. Please try again.',
            action: FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Exclude own rides
          if (data['riderId'] == widget.userId) return false;
          // Exclude invite-only rides from open public search
          final vis = data['visibility'] as String?;
          if (vis == 'invite_only') return false;
          if (_searchQ.isEmpty) return true;
          final to = (data['to'] ?? '').toString().toLowerCase();
          final from = (data['from'] ?? '').toString().toLowerCase();
          final name = (data['postedByName'] ?? '').toString().toLowerCase();
          return to.contains(_searchQ) ||
              from.contains(_searchQ) ||
              name.contains(_searchQ);
        }).toList();

        if (docs.isEmpty) {
          return PoolingEmptyState(
            icon: Icons.directions_car_outlined,
            title: _searchQ.isNotEmpty
                ? 'No rides found for "$_searchQ"'
                : 'No rides available',
            subtitle: _searchQ.isNotEmpty
                ? 'Try a different search term or browse all rides.'
                : 'No rides are posted yet. Be the first to offer one!',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return RideCard(
              rideId: doc.id,
              rideData: doc.data() as Map<String, dynamic>,
              currentUserId: widget.userId,
            );
          },
        );
      },
    );
  }
}
