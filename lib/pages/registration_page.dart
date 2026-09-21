import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String? _selectedGender;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime? _selectedDob;
  String? _selectedGender;

  bool _loading = false;
  bool _passwordObscure = true;
  bool _confirmObscure = true;

  static const List<String> _genderOptions = [
    "Male",
    "Female",
    "Other",
  ];

  // ── Palette (matches LoginPage) ──────────────
  static const navy = Color(0xFF0D1B3E);
  static const navyMid = Color(0xFF1A2F5E);
  static const yellow = Color(0xFFFFCC00);
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFFF0F2F8);
  static const greyBdr = Color(0xFFDDE0EE);
  static const txtDark = Color(0xFF0D1B3E);
  static const txtMed = Color(0xFF6B7280);
  static const txtHint = Color(0xFFB0B8D0);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF16A34A);

  // ── Animations ───────────────────────────────
  late AnimationController _heroAnim;
  late AnimationController _cardAnim;
  late AnimationController _pulseAnim;

  late Animation<double> _heroScale;
  late Animation<double> _heroFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _heroAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _heroScale = Tween<double>(begin: 0.82, end: 1.0).animate(
        CurvedAnimation(parent: _heroAnim, curve: Curves.easeOutBack));
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _heroAnim,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));

    _cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeIn));

    _pulse = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      _heroAnim.forward();
      Future.delayed(
          const Duration(milliseconds: 220), () => _cardAnim.forward());
    });
  }

  // ============================================================
  // DATE OF BIRTH
  // ============================================================

  Future<void> _pickDob() async {
    final now = DateTime.now();

    final maxDob = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: maxDob,
      firstDate: DateTime(now.year - 100),
      lastDate: maxDob,
    );

    if (picked == null) return;

    setState(() {
      _selectedDob = picked;

      _dobCtrl.text = "${picked.day.toString().padLeft(2, '0')}/"
          "${picked.month.toString().padLeft(2, '0')}/"
          "${picked.year}";
    });
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();

    int age = now.year - dob.year;

    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }

    return age;
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    // ---------------------------
    // BASIC VALIDATION
    // ---------------------------

    if (name.length < 3) {
      _snack("Enter your full name", true);
      return;
    }

    final nameRegex = RegExp(r'^[a-zA-Z]+(\s[a-zA-Z]+)*$');

    if (!nameRegex.hasMatch(name)) {
      _snack("Name should contain only letters", true);
      return;
    }

    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

    if (!emailRegex.hasMatch(email)) {
      _snack("Enter a valid email address", true);
      return;
    }

    if (_selectedDob == null) {
      _snack("Please select your date of birth", true);
      return;
    }

    if (_calculateAge(_selectedDob!) < 18) {
      _snack("You must be at least 18 years old", true);
      return;
    }

    if (_selectedGender == null) {
      _snack("Please select your gender", true);
      return;
    }

    if (password.length < 8) {
      _snack("Password must contain at least 8 characters", true);
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _snack("Password needs an uppercase letter", true);
      return;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      _snack("Password needs a lowercase letter", true);
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _snack("Password needs a number", true);
      return;
    }

    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)) {
      _snack("Password needs a special character", true);
      return;
    }

    if (password != confirmPassword) {
      _snack("Passwords do not match", true);
      return;
    }

    setState(() {
      _loading = true;
    });

    User? user;

    try {
      // ========================================================
      // 1. CREATE EMAIL ACCOUNT
      // ========================================================

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = credential.user!;

      // ========================================================
      // 2. UPDATE DISPLAY NAME
      // ========================================================

      await user.updateDisplayName(name);

      // ========================================================
      // 3. SEND EMAIL VERIFICATION
      // ========================================================

      await user.sendEmailVerification();

      // ========================================================
      // 4. CREATE FIRESTORE PROFILE
      // ========================================================
      await _firestore
          .collection("users")
          .doc(user.uid)
          .set({
        "name": name,
        "email": email,
        "dob": Timestamp.fromDate(_selectedDob!),
        "gender": _selectedGender,
        "photoUrl": "",

        // Normal registration users already completed
        // all required profile information.
        "profileComplete": true,

        "role": "commuter",
        "isBanned": false,

        // Email still needs verification.
        "verified": false,

        "authProvider": "email",
        "driverProfileComplete": false,
        "vehicleInfo": null,

        "createdAt": FieldValue.serverTimestamp(),
      });
      // ========================================================
      // 5. SIGN OUT
      // ========================================================

      await _auth.signOut();

      if (!mounted) return;

      _snack(
        "Account created! Verify your email before logging in.",
        false,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // If Firebase account was created but something after it
      // failed, try to clean it up so the email isn't left stuck
      // on a half-created account.
      try {
        if (user != null) {
          await user.delete();
        }
      } catch (_) {}

      String message;

      switch (e.code) {
        case "email-already-in-use":
          message = "This email is already registered.";
          break;

        case "invalid-email":
          message = "Please enter a valid email.";
          break;

        case "weak-password":
          message = "Password is too weak.";
          break;

        case "operation-not-allowed":
          message = "Email/password authentication is disabled.";
          break;

        default:
          message = e.message ?? "Registration failed.";
      }

      _snack(message, true);
    } on FirebaseException catch (e) {
      try {
        if (user != null) {
          await user.delete();
        }
      } catch (_) {}

      _snack("${e.plugin}: ${e.code}", true);
    } catch (e) {
      try {
        if (user != null) {
          await user.delete();
        }
      } catch (_) {}

      _snack("Something went wrong. Please try again.", true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR (matches LoginPage)
  // ============================================================

  void _snack(String msg, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: isError ? white : navy, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: isError ? white : navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: isError ? red : yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      elevation: 8,
    ));
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _heroAnim.dispose();
    _cardAnim.dispose();
    _pulseAnim.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        _buildBgDecor(),

        SafeArea(
          child: Column(children: [
            ScaleTransition(
              scale: _heroScale,
              child: FadeTransition(
                opacity: _heroFade,
                child: _buildHero(),
              ),
            ),

            FadeTransition(
              opacity: _heroFade,
              child: _buildChipStrip(),
            ),

            Expanded(
              child: SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: _buildFormCard(),
                ),
              ),
            ),
          ]),
        ),

        if (_loading) _buildLoadingOverlay(),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // BACKGROUND
  // ─────────────────────────────────────────────
  Widget _buildBgDecor() {
    return Stack(children: [
      CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
      Positioned(
          top: -30, right: -60, child: _glowOrb(280, yellow.withOpacity(0.09))),
      Positioned(
          top: 160, right: 30, child: _glowOrb(90, yellow.withOpacity(0.13))),
      Positioned(
          bottom: 220, left: -50, child: _glowOrb(180, yellow.withOpacity(0.07))),
      Positioned(top: 100, left: 20, child: _glowOrb(50, yellow.withOpacity(0.08))),
    ]);
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────────
  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: navy, size: 12),
                SizedBox(width: 4),
                Text("JOIN GHARTAK",
                    style: TextStyle(
                        color: navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4)),
              ]),
            ),
            const SizedBox(height: 12),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                    color: white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.8),
                children: [
                  TextSpan(text: "Create\n"),
                  TextSpan(text: "Account"),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text("Start sharing rides in minutes",
                style: TextStyle(
                    color: white.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w400)),
          ]),
        ),
        const SizedBox(width: 20),
        _buildCarBadge(),
      ]),
    );
  }

  Widget _buildCarBadge() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: yellow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: yellow.withOpacity(0.5),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8)),
          BoxShadow(color: yellow.withOpacity(0.2), blurRadius: 60, spreadRadius: 10),
        ],
      ),
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [white.withOpacity(0.25), Colors.transparent],
              ),
            ),
          ),
        ),
        const Center(
          child: Icon(Icons.person_add_alt_1_rounded, color: navy, size: 34),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // CHIP STRIP
  // ─────────────────────────────────────────────
  Widget _buildChipStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      child: Row(children: [
        _liveChip(),
        const SizedBox(width: 10),
        _infoChip(Icons.verified_user_outlined, "Free to Join"),
      ]),
    );
  }

  Widget _liveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: yellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: yellow.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Opacity(
            opacity: _pulse.value,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green,
                boxShadow: [
                  BoxShadow(color: green.withOpacity(0.6), blurRadius: 4, spreadRadius: 1)
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text("Quick Signup",
            style:
            TextStyle(color: white.withOpacity(0.65), fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: yellow.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: yellow.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: white.withOpacity(0.5), size: 13),
        const SizedBox(width: 6),
        Text(label,
            style:
            TextStyle(color: white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // FORM CARD
  // ─────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      decoration: const BoxDecoration(
        color: white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Sign Up",
                    style: TextStyle(
                        color: txtDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text("Tell us a bit about yourself",
                    style: TextStyle(color: txtMed, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: grey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: greyBdr),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shield_outlined, color: green, size: 12),
                SizedBox(width: 5),
                Text("SECURE",
                    style: TextStyle(
                        color: txtMed, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ]),
            ),
          ]),

          const SizedBox(height: 28),

          _inputField(
            ctrl: _nameCtrl,
            label: "Full Name",
            hint: "e.g. Deep Chaudhari",
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 16),

          _inputField(
            ctrl: _emailCtrl,
            label: "Email Address",
            hint: "@example.com",
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          _inputField(
            ctrl: _dobCtrl,
            label: "Date of Birth",
            hint: "DD/MM/YYYY",
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: _pickDob,
          ),

          const SizedBox(height: 16),

          _genderField(),

          const SizedBox(height: 16),

          _inputField(
            ctrl: _passwordCtrl,
            label: "Password",
            hint: "Min. 8 characters",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _passwordObscure,
            onToggleObscure: () =>
                setState(() => _passwordObscure = !_passwordObscure),
          ),

          const SizedBox(height: 16),

          _inputField(
            ctrl: _confirmPasswordCtrl,
            label: "Confirm Password",
            hint: "Re-enter password",
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            obscure: _confirmObscure,
            onToggleObscure: () =>
                setState(() => _confirmObscure = !_confirmObscure),
          ),

          const SizedBox(height: 24),

          // CREATE ACCOUNT BUTTON
          GestureDetector(
            onTap: _loading ? null : _register,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: yellow.withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                  BoxShadow(color: yellow.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.centerRight,
                        colors: [white.withOpacity(0.22), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _loading ? "Creating account..." : "Create Account",
                    style: const TextStyle(
                        color: navy, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                  ),
                  if (!_loading) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, color: navy, size: 20),
                  ],
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 22),

          Row(children: [
            Expanded(child: Divider(color: greyBdr, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text("OR",
                  style: TextStyle(color: txtHint, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
            Expanded(child: Divider(color: greyBdr, thickness: 1)),
          ]),

          const SizedBox(height: 22),

          // BACK TO LOGIN
          GestureDetector(
            onTap: _loading ? null : () => Navigator.pop(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: grey,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: greyBdr, width: 1.5),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.login_rounded, color: navy, size: 18),
                SizedBox(width: 10),
                Text("Already have an account? Login",
                    style: TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: grey,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: yellow, width: 3)),
            ),
            child: Row(children: [
              const Icon(Icons.shield_outlined, color: txtMed, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text("You must be 18+ to create an account",
                    style: TextStyle(color: txtMed, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INPUT FIELD (matches LoginPage's _inputField)
  // ─────────────────────────────────────────────
  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onTap,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: txtDark, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: greyBdr, width: 1.5),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: isPassword ? obscure : false,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: const TextStyle(color: txtDark, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            hintText: hint,
            hintStyle: const TextStyle(color: txtHint, fontSize: 13),
            prefixIcon: Icon(icon, color: yellow, size: 20),
            suffixIcon: isPassword
                ? GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: txtHint,
                size: 18,
              ),
            )
                : null,
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // GENDER FIELD (dropdown styled to match)
  // ─────────────────────────────────────────────
  Widget _genderField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Gender",
          style: TextStyle(
              color: txtDark, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: greyBdr, width: 1.5),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedGender,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: txtHint),
          style: const TextStyle(color: txtDark, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            prefixIcon: Icon(Icons.wc_rounded, color: yellow, size: 20),
            hintText: "Select gender",
            hintStyle: TextStyle(color: txtHint, fontSize: 13),
          ),
          items: _genderOptions
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedGender = value);
          },
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // LOADING OVERLAY (matches LoginPage)
  // ─────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.person_add_alt_1_rounded, color: navy, size: 28),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
            const SizedBox(height: 14),
            const Text("Creating your account...",
                style: TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GRID PAINTER (subtle background texture, matches LoginPage)
// ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFCC00).withOpacity(0.03)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
