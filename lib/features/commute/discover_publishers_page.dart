import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';
import '../../data/models/commute_schedule_model.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/commute_repository.dart';
import '../../data/repositories/subscription_repository.dart';

/// Screen allowing subscribers to discover publishers and recurring commutes.
class DiscoverPublishersPage extends StatefulWidget {
  final String userId;

  const DiscoverPublishersPage({super.key, required this.userId});

  @override
  State<DiscoverPublishersPage> createState() => _DiscoverPublishersPageState();
}

class _DiscoverPublishersPageState extends State<DiscoverPublishersPage> {
  final _commuteRepo = CommuteRepository();
  final _subRepo = SubscriptionRepository();
  final _searchCtrl = TextEditingController();
  String _searchQ = '';
  int? _selectedDayFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSubscribeDialog(CommuteScheduleModel schedule) {
    final pickupCtrl = TextEditingController();
    bool autoBook = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Subscribe to ${schedule.publisherName}\'s Commute',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Route: ${schedule.from} → ${schedule.to}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pickupCtrl,
                  decoration: InputDecoration(
                    labelText: 'Preferred Pickup Point along route (optional)',
                    hintText: 'e.g. Near Wakad Bridge / Society Gate',
                    prefixIcon: const Icon(Icons.place_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto-request future seats',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Automatically submit booking request when occurrences publish',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: autoBook,
                  activeColor: AppColors.navy,
                  onChanged: (val) => setSheetState(() => autoBook = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final user = FirebaseAuth.instance.currentUser!;
                      String subName = user.displayName ?? 'Subscriber';
                      String? subPhoto = user.photoURL;

                      final uDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();
                      if (uDoc.exists) {
                        subName = uDoc.data()?['name'] ?? subName;
                        subPhoto = uDoc.data()?['photoUrl'] ?? subPhoto;
                      }

                      final sub = SubscriptionModel(
                        id: '',
                        subscriberId: user.uid,
                        subscriberName: subName,
                        subscriberPhoto: subPhoto,
                        publisherId: schedule.publisherId,
                        publisherName: schedule.publisherName,
                        scheduleId: schedule.id,
                        from: schedule.from,
                        to: schedule.to,
                        departureTime: schedule.departureTime,
                        preferredDays: schedule.daysOfWeek,
                        pickupName: pickupCtrl.text.trim().isNotEmpty
                            ? pickupCtrl.text.trim()
                            : schedule.from,
                        autoBook: autoBook,
                      );

                      final res = await _subRepo.subscribe(sub);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message ?? ''),
                            backgroundColor: res.success
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Confirm Subscription',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['All', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Discover Recurring Commutes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy),
                  hintText: 'Search destination, route, or publisher…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          // Day filter chips
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 8,
              itemBuilder: (context, i) {
                final dayVal = i == 0 ? null : i;
                final isSelected = _selectedDayFilter == dayVal;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(dayNames[i]),
                    selected: isSelected,
                    selectedColor: AppColors.navy,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.surface,
                    onSelected: (_) => setState(() => _selectedDayFilter = dayVal),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<CommuteScheduleModel>>(
              stream: _commuteRepo.streamDiscoverableSchedules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var list = snapshot.data ?? [];

                // Filter by search query
                if (_searchQ.isNotEmpty) {
                  list = list.where((s) {
                    return s.from.toLowerCase().contains(_searchQ) ||
                        s.to.toLowerCase().contains(_searchQ) ||
                        s.publisherName.toLowerCase().contains(_searchQ);
                  }).toList();
                }

                // Filter by day
                if (_selectedDayFilter != null) {
                  list = list
                      .where((s) => s.daysOfWeek.contains(_selectedDayFilter!))
                      .toList();
                }

                if (list.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.alt_route_rounded,
                    title: 'No recurring commutes found',
                    subtitle:
                        'Be the first to publish a recurring commute schedule or try adjusting your search filters.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final isOwn = item.publisherId == widget.userId;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x06000000),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.yellow.withValues(alpha: 0.2),
                                    backgroundImage: item.publisherPhoto != null
                                        ? NetworkImage(item.publisherPhoto!)
                                        : null,
                                    child: item.publisherPhoto == null
                                        ? const Icon(Icons.person, size: 18, color: AppColors.navy)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOwn ? 'You (Publisher)' : item.publisherName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      Text(
                                        'Departs at ${item.departureTime}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '₹${item.estimatedCostPerSeat}/seat',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50)),
                                  Container(width: 2, height: 22, color: AppColors.border),
                                  const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.from,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.to,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (item.waypoints.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: item.waypoints.map((w) {
                                return Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                  label: Text(
                                    w.name,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                  backgroundColor: AppColors.surfaceDim,
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.daysSummary,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (!isOwn)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                  label: const Text('Subscribe', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showSubscribeDialog(item),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
