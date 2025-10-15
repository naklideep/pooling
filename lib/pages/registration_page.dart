import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _enrollmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _register() async {
    String name = _nameController.text.trim();
    String enrollment = _enrollmentController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isEmpty || enrollment.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    if (name.length < 2) {
      _showSnackBar("Name must be at least 2 characters long");
      return;
    }
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(name)) {
      _showSnackBar("Name can only contain letters and spaces");
      return;
    }

    if (!RegExp(r'^[0-9]{15}$').hasMatch(enrollment)) {
      _showSnackBar("Enrollment must be exactly 15 digits");
      return;

  }

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters long");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential user = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user.user != null) {
        await user.user!.sendEmailVerification();

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.user!.uid)
            .set({
          "name": name,
          "enrollment": enrollment,
          "email": email,
          "createdAt": Timestamp.now(),
          "isBanned": false,
        });

        _showSnackBar("Verification email sent! Please verify before login.");
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Registration failed");
    } catch (e) {
      _showSnackBar("Something went wrong. Try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _enrollmentController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                key: Key('nameField'),
                controller: _nameController,
                decoration: InputDecoration(labelText: "Name"),
              ),
              SizedBox(height: 16),
              TextField(
                key: Key('enrollmentField'),
                controller: _enrollmentController,
                decoration: InputDecoration(labelText: "Enrollment"),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              TextField(
                key: Key('emailField'),
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                key: Key('passwordField'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                key: Key('registerButton'),
                onPressed: _register,
                child: Text("Register", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
