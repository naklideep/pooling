import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const List<String> kColleges = [
  "Asha M. Tarsadia Institute of Computer Science and Technology",
  "Babu Madhav Institute of Information Technology",
  "C. G. Bhakta Institute of Biotechnology",
  "Chhotubhai Gopalbhai Patel Institute of Technology",
  "Diwaliba Polytechnic",
  "Diwaliba College of Optometry",
  "Department of Mathematics",
  "Department of Physics",
  "Tarsadia Institute of Chemical Science",
  "Department of English",
  "Bhulabhai Vanmalibhai Patel Institute of Commerce",
  "Bhulabhai Vanmalibhai Patel Institute of Computer Science",
  "Matiya Patidar Ayurvedic Hospital",
  "Maliba Pharmacy College",
  "Maniba-Bhula Nursing College",
  "Raman Bhakta School of Architecture",
  "Shrimad Rajchandra Institute of Management & Computer Application",
  "Bhulabhai Vanmalibhai Patel Institute of Management",
  "Kishorbhai Institute of Agriculture Sciences and Research Centre",
  "Shrimad Rajchandra College of Physiotherapy",
  "Jaymin School of Fashion Design & Technology",
  "Godavariba School of Interior Design",
  "Srimca - MBA",
  "Department of Humanities",
  "Dr. Chunibhai Vallabhbhai Patel College of Pharmacy",
  "Faculty of Physical Education, Sports and Yoga",
];

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with TickerProviderStateMixin {
  final _nameCtrl       = TextEditingController();
  final _enrollmentCtrl = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _scrollCtrl     = ScrollController();

  bool    _obscurePassword = true;
  bool    _isLoading       = false;
  File?   _idCardImage;
  String? _selectedCollege;
  int     _currentStep    = 0; // 0=account, 1=institute, 2=verify

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late AnimationController _heroAnim;
  late AnimationController _stepAnim;
  late Animation<double>   _heroScale;
  late Animation<Offset>   _stepSlide;
  late Animation<double>   _stepFade;

  // Colors
  static const navy    = Color(0xFF0D1B3E);
  static const navyMid = Color(0xFF1A2F5E);
  static const yellow  = Color(0xFFFFCC00);
  static const cream   = Color(0xFFFFF9E6);
  static const white   = Color(0xFFFFFFFF);
  static const grey    = Color(0xFFF0F2F8);
  static const greyBdr = Color(0xFFDDE0EE);
  static const txtDark = Color(0xFF0D1B3E);
  static const txtMed  = Color(0xFF6B7280);
  static const txtHint = Color(0xFFB0B8D0);
  static const red     = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _stepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _heroScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _heroAnim, curve: Curves.easeOutBack));
    _stepSlide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _stepAnim, curve: Curves.easeOutCubic));
    _stepFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _stepAnim, curve: Curves.easeIn));

    _heroAnim.forward();
    _stepAnim.forward();
  }

  void _goToStep(int step) {
    _stepAnim.reset();
    setState(() => _currentStep = step);
    _stepAnim.forward();
  }

  // ── Image picker ─────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) { _snack("No image selected"); return; }
    setState(() { _idCardImage = File(picked.path); _enrollmentCtrl.text = ""; _isLoading = true; });
    try {
      final b64 = base64Encode(await _idCardImage!.readAsBytes());
      final res = await http.post(
        Uri.parse("https://ghartak-verifier.onrender.com/analyze"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"image_base64": b64}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["tampered"] == true) {
          _snack("ID appears tampered. Try another image.", isError: true);
          setState(() => _isLoading = false); return;
        }
      }
      await _extractText(_idCardImage!);
    } catch (e) {
      _snack("Error processing image: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractText(File file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognized = await recognizer.processImage(InputImage.fromFile(file));
    final regex = RegExp(r'\b\d{15}\b');
    String found = "";
    for (var block in recognized.blocks) {
      for (var line in block.lines) {
        if (regex.hasMatch(line.text)) { found = regex.firstMatch(line.text)!.group(0)!; break; }
      }
      if (found.isNotEmpty) break;
    }
    setState(() => _enrollmentCtrl.text = found.isNotEmpty ? found : "");
    _snack(found.isNotEmpty ? "Enrollment detected: $found" : "No enrollment found. Try again!", isError: found.isEmpty);
    recognizer.close();
  }

  // ── Register ─────────────────────────────────
  void _register() async {
    final name  = _nameCtrl.text.trim();
    final enrol = _enrollmentCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passwordCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) { _snack("Fill all fields", isError: true); return; }
    if (enrol.isEmpty)            { _snack("Upload ID card first", isError: true); return; }
    if (_selectedCollege == null) { _snack("Select your college", isError: true); return; }
    if (pass.length < 6)          { _snack("Password min 6 chars", isError: true); return; }

    setState(() => _isLoading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
      await _firestore.collection("users").doc(cred.user!.uid).set({
        "name": name, "enrollment": enrol, "email": email,
        "college": _selectedCollege,
        "createdAt": FieldValue.serverTimestamp(),
        "isBanned": false, "verified": false, "role": "user",
      });
      await cred.user!.sendEmailVerification();
      _snack("Account created! Check your email.");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'email-already-in-use': "Email already registered",
        'weak-password': "Password too weak",
        'invalid-email': "Invalid email format",
      };
      _snack(msgs[e.code] ?? e.message ?? "Registration failed", isError: true);
    } catch (e) {
      _snack("Something went wrong", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle,
            color: isError ? white : navy, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(
            color: isError ? white : navy, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? red : yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(14),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _enrollmentCtrl.dispose();
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _heroAnim.dispose(); _stepAnim.dispose(); _scrollCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Stack(children: [

        // ── Decorative background dots ───────────
        Positioned(top: 60, right: -30,
            child: _decorCircle(200, yellow.withOpacity(0.06))),
        Positioned(top: 140, right: 20,
            child: _decorCircle(80, yellow.withOpacity(0.1))),
        Positioned(bottom: 200, left: -40,
            child: _decorCircle(160, yellow.withOpacity(0.05))),

        SafeArea(
          child: Column(children: [

            // ── HERO TOP SECTION ────────────────
            ScaleTransition(
              scale: _heroScale,
              child: _buildHero(),
            ),

            // ── FORM CARD (slides up) ────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(children: [

                  // Step indicator
                  _buildStepBar(),

                  // Form content
                  Expanded(
                    child: SlideTransition(
                      position: _stepSlide,
                      child: FadeTransition(
                        opacity: _stepFade,
                        child: _buildStepContent(),
                      ),
                    ),
                  ),

                  // Bottom nav buttons
                  _buildNavButtons(),
                ]),
              ),
            ),
          ]),
        ),

        // Loading
        if (_isLoading)
          Container(color: Colors.black54,
              child: Center(child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 52, height: 52,
                      decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.directions_car_rounded, color: navy, size: 30)),
                  const SizedBox(height: 14),
                  const CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  const Text("Processing...", style: TextStyle(color: navy,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ))),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // HERO — navy bg with bold typography
  // ─────────────────────────────────────────────
  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: yellow.withOpacity(0.3)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: yellow, size: 16),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Yellow pill tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt, color: navy, size: 13),
                SizedBox(width: 4),
                Text("NEW ACCOUNT", style: TextStyle(color: navy,
                    fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ]),
            ),
            const SizedBox(height: 10),
            const Text("Join\nGharTak",
                style: TextStyle(color: white, fontSize: 34,
                    fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text("Campus rides, made simple",
                style: TextStyle(color: white.withOpacity(0.5),
                    fontSize: 13, fontWeight: FontWeight.w400)),
          ]),
        ),

        // Car illustration badge
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: yellow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: yellow.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.directions_car_rounded, color: navy, size: 36),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // STEP INDICATOR BAR
  // ─────────────────────────────────────────────
  Widget _buildStepBar() {
    final steps = ["Account", "Institute", "ID Card"];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(children: [
        Row(children: List.generate(3, (i) {
          final active   = i == _currentStep;
          final done     = i < _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: () => _goToStep(i),
              child: Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: done ? yellow : active ? navy : greyBdr,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ]),
            ),
          );
        })),
        const SizedBox(height: 10),
        Row(children: List.generate(3, (i) {
          final active = i == _currentStep;
          final done   = i < _currentStep;
          return Expanded(child: Text(steps[i],
              style: TextStyle(
                fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: done ? yellow : active ? navy : txtHint,
              )));
        })),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // STEP CONTENT
  // ─────────────────────────────────────────────
  Widget _buildStepContent() {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: [
        _buildStep0(),
        _buildStep1(),
        _buildStep2(),
      ][_currentStep],
    );
  }

  // STEP 0 — Account details
  Widget _buildStep0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepTitle("Your Account", "Let's set up your login details"),
      const SizedBox(height: 20),
      _inputField(ctrl: _nameCtrl, label: "Full Name",
          hint: "Rahul Patel", icon: Icons.person_outline_rounded),
      const SizedBox(height: 14),
      _inputField(ctrl: _emailCtrl, label: "Email Address",
          hint: "rahul@example.com", icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _inputField(ctrl: _passwordCtrl, label: "Password",
          hint: "Min. 6 characters", icon: Icons.lock_outline_rounded,
          isPassword: true),
      const SizedBox(height: 24),

      // Info strip
      _infoStrip(Icons.shield_outlined, "Your password is encrypted and secure"),
    ]);
  }

  // STEP 1 — College/Department
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepTitle("Your Institute", "Which college do you belong to?"),
      const SizedBox(height: 20),

      // College selector card — big tappable
      GestureDetector(
        onTap: _showCollegePicker,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _selectedCollege != null ? navy : grey,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _selectedCollege != null ? yellow.withOpacity(0.4) : greyBdr,
                width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _selectedCollege != null ? yellow : greyBdr,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.school_rounded,
                  color: _selectedCollege != null ? navy : txtHint, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("College / Department",
                  style: TextStyle(
                      color: _selectedCollege != null ? yellow.withOpacity(0.7) : txtHint,
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(
                _selectedCollege ?? "Tap to select your institute",
                style: TextStyle(
                    color: _selectedCollege != null ? white : txtMed,
                    fontSize: 13,
                    fontWeight: _selectedCollege != null ? FontWeight.w700 : FontWeight.w400),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ])),
            Icon(Icons.keyboard_arrow_right_rounded,
                color: _selectedCollege != null ? yellow : txtHint, size: 24),
          ]),
        ),
      ),

      const SizedBox(height: 20),
      _infoStrip(Icons.location_city_outlined, "Tarsadia University — Bardoli, Gujarat"),
    ]);
  }

  // STEP 2 — ID Card
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepTitle("Verify Identity", "Upload your student ID card"),
      const SizedBox(height: 20),

      // Upload area
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: _idCardImage != null ? null : 160,
          decoration: BoxDecoration(
            color: _idCardImage != null ? Colors.transparent : grey,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _idCardImage != null ? yellow : greyBdr,
                width: _idCardImage != null ? 2 : 1.5,
                style: _idCardImage != null ? BorderStyle.solid : BorderStyle.solid),
          ),
          child: _idCardImage != null
              ? Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(_idCardImage!, width: double.infinity,
                  height: 180, fit: BoxFit.cover),
            ),
            Positioned(top: 10, right: 10, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(10)),
              child: const Text("CHANGE", style: TextStyle(color: yellow,
                  fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            )),
            if (_enrollmentCtrl.text.isNotEmpty)
              Positioned(bottom: 10, left: 10, right: 10, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: navy.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: yellow, size: 16),
                  const SizedBox(width: 8),
                  Text("Enrollment: ${_enrollmentCtrl.text}",
                      style: const TextStyle(color: white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              )),
          ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: greyBdr, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add_photo_alternate_outlined, color: txtMed, size: 28),
            ),
            const SizedBox(height: 12),
            const Text("Tap to upload ID card",
                style: TextStyle(color: txtMed, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text("JPG, PNG supported",
                style: TextStyle(color: txtHint, fontSize: 11)),
          ]),
        ),
      ),

      const SizedBox(height: 16),

      // Enrollment result
      if (_enrollmentCtrl.text.isEmpty && _idCardImage == null)
        _infoStrip(Icons.info_outline_rounded,
            "Your 15-digit enrollment number will be auto-extracted")
      else if (_enrollmentCtrl.text.isEmpty && _idCardImage != null)
        _infoStrip(Icons.warning_amber_rounded,
            "Could not extract enrollment. Enter manually", isWarn: true)
      else
        _infoStrip(Icons.check_circle_outline_rounded,
            "Enrollment ${_enrollmentCtrl.text} detected!", isSuccess: true),

      // Manual enrollment fallback
      if (_idCardImage != null && _enrollmentCtrl.text.isEmpty) ...[
        const SizedBox(height: 14),
        _inputField(ctrl: _enrollmentCtrl, label: "Enrollment Number (manual)",
            hint: "15-digit number", icon: Icons.tag_rounded,
            keyboardType: TextInputType.number),
      ],
    ]);
  }

  // ─────────────────────────────────────────────
  // NAV BUTTONS
  // ─────────────────────────────────────────────
  Widget _buildNavButtons() {
    final isLast = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(children: [

        // Back btn (hidden on step 0)
        if (_currentStep > 0) ...[
          GestureDetector(
            onTap: () => _goToStep(_currentStep - 1),
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: grey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: greyBdr),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: txtDark, size: 18),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Next / Register btn
        Expanded(
          child: GestureDetector(
            onTap: _isLoading ? null : () {
              if (isLast) { _register(); } else { _goToStep(_currentStep + 1); }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: yellow.withOpacity(0.4),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  isLast ? "Create Account" : "Continue",
                  style: const TextStyle(color: navy, fontSize: 15,
                      fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
                const SizedBox(width: 8),
                Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    color: navy, size: 18),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // COLLEGE PICKER BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showCollegePicker() {
    List<String> filtered = List.from(kColleges);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: greyBdr, borderRadius: BorderRadius.circular(2))),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
              child: Row(children: [
                Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.school_rounded, color: yellow, size: 22)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Select Institute", style: TextStyle(color: txtDark,
                      fontSize: 17, fontWeight: FontWeight.w900)),
                  Text("Tarsadia University campuses",
                      style: TextStyle(color: txtHint, fontSize: 11)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(ctx),
                    child: Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close, color: txtMed, size: 16))),
              ]),
            ),

            // Search
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: greyBdr)),
              child: TextField(
                style: const TextStyle(color: txtDark, fontSize: 13),
                decoration: const InputDecoration(border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: txtHint, size: 18),
                    hintText: "Search your college...",
                    hintStyle: TextStyle(color: txtHint, fontSize: 13)),
                onChanged: (v) => setInner(() {
                  filtered = kColleges.where((c) => c.toLowerCase().contains(v.toLowerCase())).toList();
                }),
              ),
            ),
            const SizedBox(height: 8),

            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text("${filtered.length} institutes",
                      style: const TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),

            const Divider(height: 1, color: greyBdr),

            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, color: greyBdr, size: 48),
                const SizedBox(height: 10),
                const Text("No results", style: TextStyle(color: txtHint, fontSize: 13)),
              ]))
                  : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1, color: greyBdr, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final c    = filtered[i];
                  final isSel = c == _selectedCollege;
                  return InkWell(
                    onTap: () { setState(() => _selectedCollege = c); Navigator.pop(ctx); },
                    child: Container(
                      color: isSel ? yellow.withOpacity(0.07) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(children: [
                        Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: isSel ? yellow : grey,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.school_rounded,
                                color: isSel ? navy : txtHint, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(c, style: TextStyle(color: txtDark,
                            fontSize: 13, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500))),
                        if (isSel) Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.check_rounded, color: navy, size: 14)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Widget _stepTitle(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: txtDark,
          fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: txtMed, fontSize: 13)),
    ]);
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool readOnly   = false,
    TextInputType? keyboardType,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: txtDark,
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: greyBdr),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: isPassword ? _obscurePassword : false,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: const TextStyle(color: txtDark, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintText: hint,
            hintStyle: const TextStyle(color: txtHint, fontSize: 13),
            prefixIcon: Icon(icon, color: yellow, size: 20),
            suffixIcon: isPassword ? GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(_obscurePassword
                    ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: txtHint, size: 18)) : null,
          ),
        ),
      ),
    ]);
  }

  Widget _infoStrip(IconData icon, String msg, {bool isWarn = false, bool isSuccess = false}) {
    final bg   = isSuccess ? const Color(0xFFE8F9EE) : isWarn ? const Color(0xFFFFF8E1) : grey;
    final clr  = isSuccess ? const Color(0xFF16A34A) : isWarn ? const Color(0xFFD97706) : txtMed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: clr, width: 3)),
      ),
      child: Row(children: [
        Icon(icon, color: clr, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: TextStyle(color: clr,
            fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}