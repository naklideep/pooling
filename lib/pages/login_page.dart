import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'registration_page.dart';
import 'admin_dashboard_page.dart'; // 🆕 Admin page import

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

// 🧩 Your admin email
const String adminEmail = "chaudharideep1106@gmail.com";

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _login() async {
    try {
      // 🟦 Step 1: Try to sign in
      UserCredential user = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user.user != null) {
        if (!user.user!.emailVerified) {
          await _auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please verify your email before logging in.")),
          );
          return;
        }

        final userEmail = user.user!.email;

        // 🟩 Step 2: Check if admin
        if (userEmail == adminEmail) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
          );
          return;
        }

        // 🟥 Step 3: Check if user is banned in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.user!.uid)
            .get();

        if (userDoc.exists && (userDoc['isBanned'] == true)) {
          await _auth.signOut(); // logout immediately
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You are banned from the app."),
              backgroundColor: Colors.redAccent,
            ),
          );

          return;
        }

        // ✅ Step 4: Normal user — go to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Login Failed"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _forgotPassword() {
    if (_emailController.text.isNotEmpty) {
      _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email first")),
      );
    }
  }

  void _createAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.directions_car, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "Welcome to GharTak",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value!);
                    },
                  ),
                  const Text("Remember Me"),
                  const Spacer(),
                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text("Forgot Password?"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Login", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _createAccount,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Create Account", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
