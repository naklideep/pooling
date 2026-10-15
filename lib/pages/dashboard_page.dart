import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'find_ride_widget.dart';
import 'login_page.dart';
import 'post_ride.dart';
import 'profile_page.dart';
import 'saved_routes_page.dart';
import 'your_rides_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color _navy = Color(0xFF1A2340);
  static const Color _yellow = Color(0xFFFFCC00);
  static const Color _background = Color(0xFFF3F5F9);
  static const Color _muted = Color(0xFF7B8497);

  late final TabController _tabController;
  String _userName = 'there';
  String? _userPhotoUrl;
  bool _isLoadingUser = true;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }

    var name = user.displayName?.trim();
    var photoUrl = user.photoURL;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      final firestoreName = data?['name'];
      if (firestoreName is String && firestoreName.trim().isNotEmpty) {
        name = firestoreName.trim();
      }

      final firestorePhoto = data?['photoUrl'];
      if (firestorePhoto is String && firestorePhoto.trim().isNotEmpty) {
        photoUrl = firestorePhoto.trim();
      }
    } catch (error) {
      // Firebase profile data is optional for rendering the dashboard.
      debugPrint('Pooling: unable to load profile data: $error');
    }

    if (!mounted) return;
    setState(() {
      _userName = (name == null || name.isEmpty) ? 'there' : name;
      _userPhotoUrl = photoUrl;
      _isLoadingUser = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Log out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will need to sign in again to access your rides.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: _navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
      );
    } catch (error) {
      if (mounted) _showSnack('Could not log out. Please try again.', isError: true);
      debugPrint('Pooling: sign out failed: $error');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFD83B45) : _navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage()),
    );
  }

  void _openSettings() {
    final email = _auth.currentUser?.email ?? 'Not available';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DDE6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Settings & account',
                style: TextStyle(
                  color: _navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _yellow,
                      child: Icon(Icons.email_outlined, color: _navy),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: _navy),
                title: const Text('Manage profile'),
                subtitle: const Text('Update your personal details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProfile();
                },
              ),
              const Divider(height: 20),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: _muted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only share ride and location information with people authorized for that ride.',
                      style: TextStyle(color: _muted, height: 1.4, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Pooling • Carpool together',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return LoginPage();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        final previous = _lastBackPressed;
        if (previous == null ||
            now.difference(previous) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          _showSnack('Press back again to exit');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        drawer: _buildDrawer(user),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildIntroCard(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    PostRidePage(),
                    FindRideWidget(userId: user.uid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 12,
        18,
        22,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => _HeaderIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Open navigation menu',
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.route_rounded, color: _navy, size: 25),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pooling',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Better rides, together.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Open profile',
            child: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _yellow, width: 2),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.14),
                  backgroundImage: _userPhotoUrl != null &&
                      _userPhotoUrl!.trim().isNotEmpty
                      ? NetworkImage(_userPhotoUrl!)
                      : null,
                  child: _userPhotoUrl == null || _userPhotoUrl!.trim().isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingUser ? 'Welcome back' : 'Hey, $_userName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Where are you headed today?',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_outlined, color: _navy, size: 17),
                SizedBox(width: 5),
                Text(
                  'Share the ride',
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: _yellow,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: _navy,
          unselectedLabelColor: _muted,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_road_rounded, size: 19),
                  SizedBox(width: 7),
                  Text('Post a ride'),
                ],
              ),
            ),
            Tab(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 19),
                  SizedBox(width: 7),
                  Text('Find a ride'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(User user) {
    return Drawer(
      backgroundColor: _navy,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _yellow,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: _userPhotoUrl != null &&
                          _userPhotoUrl!.trim().isNotEmpty
                          ? NetworkImage(_userPhotoUrl!)
                          : null,
                      child: _userPhotoUrl == null || _userPhotoUrl!.trim().isEmpty
                          ? const Icon(Icons.person_rounded, color: _navy, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'WELCOME TO',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pooling',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userName == 'there' ? (user.email ?? 'Your carpool community') : _userName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.13), height: 1),
            ),
            const SizedBox(height: 10),
            _drawerItem(
              icon: Icons.home_rounded,
              title: 'Dashboard',
              onTap: () => Navigator.pop(context),
              selected: true,
            ),
            _drawerItem(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                _openProfile();
              },
            ),
            _drawerItem(
              icon: Icons.directions_car_outlined,
              title: 'Your rides',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => YourRidesPage(userId: user.uid),
                  ),
                );
              },
            ),
            _drawerItem(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved routes',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SavedRoutesPage(userId: user.uid),
                  ),
                );
              },
            ),
            _drawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings & account',
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.13), height: 1),
            ),
            const SizedBox(height: 8),
            _drawerItem(
              icon: Icons.logout_rounded,
              title: 'Log out',
              onTap: _logout,
              isDestructive: true,
            ),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route_rounded, color: _navy),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Pooling • Carpool together',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool isDestructive = false,
  }) {
    final foreground = isDestructive ? const Color(0xFFFF777F) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        tileColor: selected ? Colors.white.withOpacity(0.09) : null,
        leading: Icon(
          icon,
          color: isDestructive ? foreground : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.circle, color: _yellow, size: 8)
            : Icon(
          Icons.chevron_right_rounded,
          color: isDestructive ? foreground.withOpacity(0.6) : Colors.white38,
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 23),
          ),
        ),
      ),
    );
  }
}
