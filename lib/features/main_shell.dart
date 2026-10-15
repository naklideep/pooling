import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_colors.dart';
import 'home/home_tab.dart';
import 'find_ride/find_ride_tab.dart';
import 'offer_ride/offer_ride_tab.dart';
import 'my_trips/my_trips_tab.dart';
import 'profile/profile_tab.dart';

/// Root navigation shell.
///
/// Maintains 5 persistent bottom-navigation destinations.
/// Uses [IndexedStack] so each tab keeps its widget state
/// across tab switches (no unnecessary Firebase re-fetches).
class MainShell extends StatefulWidget {
  /// Optionally open a specific tab on launch (0-indexed).
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?._onTabTapped(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  void _showExitSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If not on home tab, navigate home first.
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        // Double-back to exit when already on home.
        final now = DateTime.now();
        final prev = _lastBackPressed;
        if (prev == null || now.difference(prev) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          _showExitSnack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeTab(userId: uid),
            FindRideTab(userId: uid),
            OfferRideTab(userId: uid),
            MyTripsTab(userId: uid),
            ProfileTab(userId: uid),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.navy,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Find Ride',
            ),
            BottomNavigationBarItem(
              icon: _OfferIcon(active: false),
              activeIcon: _OfferIcon(active: true),
              label: 'Offer Ride',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car_rounded),
              label: 'My Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom "Offer Ride" centre icon with a yellow background highlight.
class _OfferIcon extends StatelessWidget {
  final bool active;
  const _OfferIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active ? AppColors.yellow : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        active ? Icons.add_road_rounded : Icons.add_road_outlined,
        size: active ? 22 : 20,
        color: active ? AppColors.navy : AppColors.textSecondary,
      ),
    );
  }
}
