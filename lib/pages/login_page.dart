import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'registration_page.dart';
import 'admin_dashboard_page.dart';

const String adminEmail = "chaudharideep1106@gmail.com";

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Login function
  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Email and password cannot be empty");
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnack("Enter a valid email");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential user = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user.user == null) throw FirebaseAuthException(code: "unknown", message: "Login failed");

      if (!user.user!.emailVerified) {
        await _auth.signOut();
        _showSnack("Please verify your email before logging in.");
        setState(() => _isLoading = false);
        return;
      }

      // 🔥 ENHANCED ADMIN CHECK - Check both email AND Firestore role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.user!.uid)
          .get();

      // Check if user is banned first
      if (userDoc.exists && (userDoc.data()?['isBanned'] == true)) {
        await _auth.signOut();
        _showSnack("❌ You are banned from the app", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Check admin by email OR role field
      bool isAdmin = user.user!.email == adminEmail;

      // Also check if user has 'admin' role in Firestore (more secure)
      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        isAdmin = true;
      }

      if (isAdmin) {
        // Ensure admin role is set in Firestore (for first-time admin)
        if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.user!.uid)
              .set({
            'role': 'admin',
            'email': user.user!.email,
            'name': user.user!.displayName ?? 'Admin',
            'isAdmin': true, // Extra flag for queries
          }, SetOptions(merge: true));
        }

        _showSnack("✅ Welcome Admin!", isError: false);

        // Navigate to Admin Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Regular user - Navigate to normal dashboard
      _showSnack("✅ Login successful!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = "❌ No user found with this email";
          break;
        case 'wrong-password':
          msg = "❌ Incorrect password";
          break;
        case 'network-request-failed':
          msg = "❌ Network error. Check your connection";
          break;
        case 'too-many-requests':
          msg = "⚠️ Too many attempts. Try again later";
          break;
        case 'user-disabled':
          msg = "❌ This account has been disabled";
          break;
        default:
          msg = e.message ?? "❌ Login failed";
      }
      _showSnack(msg, isError: true);
    } catch (e) {
      _showSnack("❌ An error occurred: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnack("⚠️ Enter your email first");
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showSnack("📧 Password reset email sent! Check your inbox");
    } catch (e) {
      _showSnack("❌ Error sending reset email", isError: true);
    }
  }

  void _createAccount() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RegistrationPage()));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SingleChildScrollView(
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
                const SizedBox(height: 8),
                const Text(
                  "Login to continue",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _login(), // Press enter to login
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val!),
                    ),
                    const Text("Remember Me"),
                    const Spacer(),
                    TextButton(
                        onPressed: _forgotPassword,
                        child: const Text("Forgot Password?")
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Login", style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _createAccount,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Create Account", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Logging in...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}