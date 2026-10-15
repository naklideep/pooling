import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../pages/login_page.dart';
import '../../pages/saved_routes_page.dart';
import '../vehicles/vehicles_page.dart';
import '../safety/safety_sheet.dart';
import '../main_shell.dart';

/// Profile tab — shows user information, stats, preferences and account actions.
///
/// Surfaces all key user data fields and provides actions for
/// editing UPI, vehicle info, logout, and account management.
class ProfileTab extends StatefulWidget {
  final String userId;
  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (mounted) {
        setState(() {
          _userData = doc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Log out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will need to sign in again to access your rides.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Your account'),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.yellow),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.yellow,
                onRefresh: _loadUser,
                child: _buildContent(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final user = FirebaseAuth.instance.currentUser;
    final name =
        _userData?['name'] as String? ?? user?.displayName ?? 'Pooling User';
    final email = _userData?['email'] as String? ?? user?.email ?? '';
    final photoUrl = _userData?['photoUrl'] as String?;
    final role = _userData?['role'] as String? ?? 'commuter';
    final upiId = _userData?['upiId'] as String?;
    final isVerified = user?.emailVerified ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Avatar + name ─────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.yellow,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isVerified
                            ? AppColors.success
                            : AppColors.textSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        isVerified ? Icons.verified : Icons.info_outline,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Stats row ─────────────────────────────────────────────────
        _buildStatsRow(),
        const SizedBox(height: 24),

        // ── Account details ───────────────────────────────────────────
        _buildSectionHeader('Account Details'),
        _InfoTile(icon: Icons.badge_outlined, label: 'Full Name', value: name),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
          trailing: isVerified
              ? const Icon(Icons.verified, color: AppColors.success, size: 18)
              : TextButton(
                  onPressed: () async {
                    await user?.sendEmailVerification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email sent!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Verify'),
                ),
        ),
        if (upiId != null && upiId.isNotEmpty)
          _InfoTile(
            icon: Icons.payment_outlined,
            label: 'UPI ID',
            value: upiId,
            onTap: () => _editUpi(upiId),
            trailing: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
          )
        else
          _InfoTile(
            icon: Icons.payment_outlined,
            label: 'UPI ID',
            value: 'Not set',
            onTap: () => _editUpi(null),
            trailing: const Icon(
              Icons.add_circle_outline,
              size: 16,
              color: AppColors.navy,
            ),
          ),
        const SizedBox(height: 24),

        // ── Quick links ───────────────────────────────────────────────
        _buildSectionHeader('Manage'),
        _ActionTile(
          icon: Icons.bookmark_border_rounded,
          label: 'Saved Routes',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SavedRoutesPage(userId: widget.userId),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.directions_car_outlined,
          label: 'My Vehicles',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VehiclesPage(userId: widget.userId),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.history_rounded,
          label: 'Ride History',
          onTap: () {
            MainShell.switchToTab(context, 3);
          },
        ),
        _ActionTile(
          icon: Icons.shield_outlined,
          label: 'Safety & Support Report',
          onTap: () {
            SafetySheet.show(context);
          },
        ),
        const SizedBox(height: 24),

        // ── Danger zone ───────────────────────────────────────────────
        _buildSectionHeader('Account'),
        _ActionTile(
          icon: Icons.logout_rounded,
          label: _signingOut ? 'Signing out…' : 'Log out',
          color: AppColors.error,
          onTap: _signingOut ? null : _signOut,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Pooling • Better rides, together.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('riderId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snap) {
        final total = snap.data?.docs.length ?? 0;
        final completed =
            snap.data?.docs
                .where((d) => (d.data() as Map)['status'] == 'completed')
                .length ??
            0;
        return Row(
          children: [
            _StatCard(label: 'Rides Offered', value: '$total'),
            const SizedBox(width: 10),
            _StatCard(label: 'Completed', value: '$completed'),
            const SizedBox(width: 10),
            _StatCard(label: 'Rating', value: '—'),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Future<void> _editUpi(String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UPI ID'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'yourname@upi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && mounted) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'upiId': res});
      _loadUser();
    }
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color == AppColors.error
              ? AppColors.error.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color == AppColors.error
                ? AppColors.error.withValues(alpha: 0.2)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
