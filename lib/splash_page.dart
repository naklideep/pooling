import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/admin_dashboard_page.dart';

const String adminEmail = "chaudharideep1106@gmail.com";

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500)); // let Firebase hydrate

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !user.emailVerified) {
      _goTo(LoginPage());
      return;
    }

    // Fetch Firestore doc to check ban + role
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Banned check
      if (doc.exists && doc.data()?['isBanned'] == true) {
        await FirebaseAuth.instance.signOut();
        _goTo(LoginPage());
        return;
      }

      // Role check
      bool isAdmin = user.email == adminEmail ||
          (doc.exists && doc.data()?['role'] == 'admin');

      if (isAdmin) {
        _goTo(const AdminDashboardPage());
      } else {
        _goTo(DashboardPage());
      }
    } catch (_) {
      // On any error (e.g. no network), fall back to login
      await FirebaseAuth.instance.signOut();
      _goTo(LoginPage());
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reuse the same gradient as LoginPage for a seamless feel
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
              Color(0xFF7E22CE),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_rounded, size: 80, color: Colors.white),
              SizedBox(height: 24),
              Text(
                "GharTak",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ],
          ),
        ),
      ),
    );
  }
}
