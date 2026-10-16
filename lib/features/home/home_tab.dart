import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/ride_card.dart';
import '../../core/widgets/loading_states.dart';
import '../main_shell.dart';
import '../notifications/notification_center_page.dart';
import '../invitations/invitations_page.dart';
import '../commute/discover_publishers_page.dart';
import '../commute/my_subscriptions_page.dart';
import '../commute/my_schedules_page.dart';

/// Home tab — entry point of the main experience.
///
/// Displays a greeting, upcoming trip card, nearby available rides,
/// and quick shortcuts to Find/Offer Ride.
class HomeTab extends StatefulWidget {
  final String userId;
  const HomeTab({super.key, required this.userId});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _userName = '';
  String? _photoUrl;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final auth = FirebaseAuth.instance.currentUser;
      var name = auth?.displayName?.trim() ?? '';
      var photo = auth?.photoURL;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();
      if (data != null) {
        final fn = data['name'];
        if (fn is String && fn.trim().isNotEmpty) name = fn.trim();
        final fp = data['photoUrl'];
        if (fp is String && fp.trim().isNotEmpty) photo = fp.trim();
      }
      if (!mounted) return;
      setState(() {
        _userName = name.isNotEmpty ? name.split(' ').first : 'there';
        _photoUrl = photo;
        _loadingUser = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildGreeting()),
          SliverToBoxAdapter(child: _buildQuickActions(context)),
          SliverToBoxAdapter(child: _buildSectionTitle('Available Nearby')),
          _buildNearbyRides(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return PoolingHeader(
      trailing: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationCenterPage(userId: widget.userId),
            ),
          );
        },
        child: Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Greeting ──────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loadingUser ? greeting : '$greeting, $_userName 👋',
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Where are you headed today?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.yellow,
            backgroundImage: _photoUrl != null
                ? NetworkImage(_photoUrl!)
                : null,
            child: _photoUrl == null
                ? Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.search_rounded,
                  label: 'Find a Ride',
                  subtitle: 'Browse single rides',
                  color: AppColors.navy,
                  onTap: () {
                    MainShell.switchToTab(context, 1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_road_rounded,
                  label: 'Offer a Ride',
                  subtitle: 'Share your journey',
                  color: AppColors.yellow,
                  onTap: () {
                    MainShell.switchToTab(context, 2);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.repeat_rounded,
                  label: 'My Commutes',
                  subtitle: 'Publisher schedules',
                  color: AppColors.navy,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MySchedulesPage(userId: widget.userId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.mark_email_unread_outlined,
                  label: 'Ride Invites',
                  subtitle: 'Sent & received',
                  color: AppColors.yellowDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvitationsPage(userId: widget.userId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.explore_outlined,
                  label: 'Discover Routes',
                  subtitle: 'Find recurring publishers',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DiscoverPublishersPage(userId: widget.userId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.subscriptions_outlined,
                  label: 'Subscriptions',
                  subtitle: 'Your recurring routes',
                  color: const Color(0xFF5C6BC0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MySubscriptionsPage(userId: widget.userId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          GestureDetector(
            onTap: () {
              MainShell.switchToTab(context, 1);
            },
            child: Text(
              'See all',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby rides ─────────────────────────────────────────────────────────

  Widget _buildNearbyRides() {
    final query = FirebaseFirestore.instance
        .collection('rides')
        .where('status', whereIn: ['pending', 'published'])
        .orderBy('timestamp', descending: true)
        .limit(5);

    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: RideCardSkeleton(),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _ErrorState(message: 'Could not load rides'),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          // Filter out own rides
          final filtered = docs
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['riderId'] !=
                    widget.userId,
              )
              .toList();

          if (filtered.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyState(),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              return RideCard(
                rideId: doc.id,
                rideData: data,
                currentUserId: widget.userId,
                compact: true,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isYellow = color == AppColors.yellow;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isYellow ? AppColors.yellow : AppColors.navy,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppThemeHelper.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isYellow
                    ? AppColors.navy.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isYellow ? AppColors.navy : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isYellow ? AppColors.navy : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: isYellow
                    ? AppColors.navy.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              size: 36,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No rides nearby yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to offer a ride in your area!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal helper to avoid importing AppTheme for shadow.
class AppThemeHelper {
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0x14000000),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
