import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  File? _idCardImage;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pick ID Card and verify tamper
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) {
      _showSnackBar("No image selected");
      return;
    }

    setState(() {
      _idCardImage = File(picked.path);
      _enrollmentController.text = "";
      _isLoading = true;
    });

    try {
      final bytes = await _idCardImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse("https://ghartak-verifier.onrender.com/analyze"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"image_base64": base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["tampered"] == true) {
          _showSnackBar("⚠️ ID appears tampered. Try another image.");
          setState(() => _isLoading = false);
          return;
        }
      } else {
        _showSnackBar("⚠️ Verification service error. Skipping tamper check.");
      }

      await _extractTextFromImage(_idCardImage!);

    } catch (e) {
      _showSnackBar("❌ Error processing image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Extract Enrollment Number
  Future<void> _extractTextFromImage(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    String extractedEnrollment = "";
    final RegExp enrollmentRegex = RegExp(r'\b\d{15}\b');

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        if (enrollmentRegex.hasMatch(line.text)) {
          extractedEnrollment = enrollmentRegex.firstMatch(line.text)!.group(0)!;
          break;
        }
      }
      if (extractedEnrollment.isNotEmpty) break;
    }

    if (extractedEnrollment.isNotEmpty) {
      setState(() {
        _enrollmentController.text = extractedEnrollment;
      });
      _showSnackBar("✅ Enrollment detected: $extractedEnrollment");
    } else {
      _showSnackBar("⚠️ No enrollment number found. Try again!");
    }

    textRecognizer.close();
  }

  // Registration logic compatible with your rules
  // Registration logic - simplified without enrollment check
  void _register() async {
    String name = _nameController.text.trim();
    String enrollment = _enrollmentController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    if (enrollment.isEmpty) {
      _showSnackBar("Please upload your ID card to extract enrollment");
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Create Firebase Auth User
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User user = userCred.user!;

      // 2️⃣ Create Firestore document immediately (no enrollment check)
      await _firestore.collection("users").doc(user.uid).set({
        "name": name,
        "enrollment": enrollment,
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),
        "isBanned": false,
        "verified": false,
        "role": "user", // Default role
      });

      // 3️⃣ Send email verification
      await user.sendEmailVerification();

      _showSnackBar("✅ Registration successful! Please verify your email.");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = "❌ This email is already registered";
          break;
        case 'weak-password':
          errorMsg = "❌ Password is too weak";
          break;
        case 'invalid-email':
          errorMsg = "❌ Invalid email format";
          break;
        default:
          errorMsg = e.message ?? "❌ Registration failed";
      }
      _showSnackBar(errorMsg);
    } catch (e) {
      _showSnackBar("❌ Something went wrong: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Name"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _enrollmentController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Enrollment (auto-filled from ID)",
                  suffixIcon: Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
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
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.photo_library),
                label: Text("Select ID Card from Gallery"),
              ),
              if (_idCardImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(_idCardImage!, height: 150),
                ),
              SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text("Register", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
