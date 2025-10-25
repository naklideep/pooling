import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
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

  // 🖼️ Pick ID Card from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _idCardImage = File(picked.path);
      });
      await _extractTextFromImage(_idCardImage!);
    } else {
      _showSnackBar("No image selected");
    }
  }

  // 🧠 Extract Enrollment Number from Image
  Future<void> _extractTextFromImage(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    String extractedEnrollment = "";
    final RegExp enrollmentRegex = RegExp(r'\b\d{15}\b');

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        if (enrollmentRegex.hasMatch(line.text)) {
          extractedEnrollment =
          enrollmentRegex.firstMatch(line.text)!.group(0)!;
          break;
        }
      }
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

  // 🔐 Registration Logic
  void _register() async {
    String name = _nameController.text.trim();
    String enrollment = _enrollmentController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    if (enrollment.isEmpty) {
      _showSnackBar("Please upload your ID card to extract enrollment");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔍 Check if enrollment already exists
      final existingUser = await FirebaseFirestore.instance
          .collection("users")
          .where("enrollment", isEqualTo: enrollment)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showSnackBar("⚠️ Enrollment already registered!");
        setState(() => _isLoading = false);
        return;
      }

      // 👤 Create new user
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

        _showSnackBar("✅ Verification email sent! Please verify before login.");
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

              // 🧾 Enrollment field (READ-ONLY)
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

              // 🪪 Upload ID Card (Gallery)
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
