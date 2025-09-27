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
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = true;

  void _register() async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_contactController.text.trim())) {
      _showMsg("Enter a valid 10-digit contact number");
      return;
    }

    try {
      UserCredential user = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user.user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.user!.uid)
            .set({
          "name": _nameController.text.trim(),
          "enrollment": _enrollmentController.text.trim(),
          "email": _emailController.text.trim(),
          "contact": _contactController.text.trim(),
          "createdAt": Timestamp.now(),
        });

        _showMsg("Account Created Successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              TextField(controller: _nameController, decoration: InputDecoration(labelText: "Name")),
              SizedBox(height: 16),
              TextField(controller: _enrollmentController, decoration: InputDecoration(labelText: "Enrollment")),
              SizedBox(height: 16),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email")),
              SizedBox(height: 16),
              TextField(controller: _contactController, decoration: InputDecoration(labelText: "Contact Number")),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                child: Text("Register", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
