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
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _heroAnim;
  late AnimationController _formAnim;

  late Animation<double> _heroScale;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;

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

  @override
  void initState() {
    super.initState();

    _heroAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _formAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _heroScale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _heroAnim,
        curve: Curves.easeOutBack,
      ),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _formAnim,
        curve: Curves.easeOutCubic,
      ),
    );

    _formFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _formAnim,
        curve: Curves.easeIn,
      ),
    );

    _heroAnim.forward();
    _formAnim.forward();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    // Validation
    if (name.isEmpty) {
      _snack("Please enter your full name", isError: true);
      return;
    }

    if (email.isEmpty) {
      _snack("Please enter your email", isError: true);
      return;
    }

    if (password.isEmpty) {
      _snack("Please enter a password", isError: true);
      return;
    }

    if (password.length < 6) {
      _snack(
        "Password must contain at least 6 characters",
        isError: true,
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      _snack(
        "Please confirm your password",
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      _snack(
        "Passwords do not match",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("========== EMAIL REGISTRATION START ==========");

      debugPrint("1. Creating Firebase account...");

      final credential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;

      debugPrint("2. Firebase account created");
      debugPrint("UID: ${user.uid}");
      debugPrint("EMAIL: ${user.email}");

      // Update Firebase Auth display name
      await user.updateDisplayName(name);

      debugPrint("3. Display name updated");

      // Create Firestore user document
      await _firestore
          .collection("users")
          .doc(user.uid)
          .set({
        "name": name,
        "email": user.email ?? email,
        "photoUrl": "",
        "role": "user",
        "isBanned": false,
        "verified": false,
        "authProvider": "email",
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint("4. Firestore user document created");

      // Send verification email
      await user.sendEmailVerification();

      debugPrint("5. Verification email sent");

      if (!mounted) return;

      _snack(
        "Account created! Please verify your email.",
      );

      // Sign out until email is verified
      await _auth.signOut();

      if (!mounted) return;

      Navigator.pop(context);

      debugPrint("========== EMAIL REGISTRATION END ==========");
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 FIREBASE AUTH ERROR");
      debugPrint("CODE: ${e.code}");
      debugPrint("MESSAGE: ${e.message}");

      String message;

      switch (e.code) {
        case "email-already-in-use":
          message = "This email is already registered.";
          break;

        case "invalid-email":
          message = "Please enter a valid email address.";
          break;

        case "weak-password":
          message = "Password is too weak.";
          break;

        case "operation-not-allowed":
          message = "Email/password registration is disabled.";
          break;

        default:
          message = e.message ?? "Registration failed.";
      }

      _snack(message, isError: true);
    } on FirebaseException catch (e) {
      debugPrint("🔥 FIRESTORE ERROR");
      debugPrint("PLUGIN: ${e.plugin}");
      debugPrint("CODE: ${e.code}");
      debugPrint("MESSAGE: ${e.message}");

      _snack(
        "${e.plugin}: ${e.code}",
        isError: true,
      );
    } catch (e, stackTrace) {
      debugPrint("🔥 UNKNOWN ERROR");
      debugPrint("$e");
      debugPrint("$stackTrace");

      _snack(
        "Something went wrong. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _snack(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle,
              color: isError ? white : navy,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? white : navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? red : yellow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _heroAnim.dispose();
    _formAnim.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Stack(
        children: [
          Positioned(
            top: 60,
            right: -30,
            child: _decorCircle(
              200,
              yellow.withOpacity(0.06),
            ),
          ),

          Positioned(
            top: 140,
            right: 20,
            child: _decorCircle(
              80,
              yellow.withOpacity(0.1),
            ),
          ),

          Positioned(
            bottom: 200,
            left: -40,
            child: _decorCircle(
              160,
              yellow.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                ScaleTransition(
                  scale: _heroScale,
                  child: _buildHero(),
                ),

                Expanded(
                  child: SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formFade,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  20,
                                ),
                                child: _buildForm(),
                              ),
                            ),

                            _buildRegisterButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: yellow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: navy,
                          size: 30,
                        ),
                      ),

                      const SizedBox(height: 14),

                      const CircularProgressIndicator(
                        color: yellow,
                        strokeWidth: 2.5,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        "Creating account...",
                        style: TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: yellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: yellow.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: yellow,
                size: 16,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: yellow,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt,
                        color: navy,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "NEW ACCOUNT",
                        style: TextStyle(
                          color: navy,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Join\nGharTak",
                  style: TextStyle(
                    color: white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Share rides. Connect locally.",
                  style: TextStyle(
                    color: white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: yellow,
              borderRadius:
              BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: yellow.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: navy,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          "Create your account",
          style: TextStyle(
            color: txtDark,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          "Use your email to create a GharTak account.",
          style: TextStyle(
            color: txtMed,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 24),

        _inputField(
          controller: _nameCtrl,
          label: "Full Name",
          hint: "Billa Patel",
          icon: Icons.person_outline_rounded,
        ),

        const SizedBox(height: 16),

        _inputField(
          controller: _emailCtrl,
          label: "Email Address",
          hint: "billa@example.com",
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        _inputField(
          controller: _passwordCtrl,
          label: "Password",
          hint: "Minimum 6 characters",
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscurePassword,
          onToggle: () {
            setState(() {
              _obscurePassword =
              !_obscurePassword;
            });
          },
        ),

        const SizedBox(height: 16),

        _inputField(
          controller: _confirmPasswordCtrl,
          label: "Confirm Password",
          hint: "Re-enter your password",
          icon: Icons.lock_reset_outlined,
          isPassword: true,
          obscure: _obscureConfirmPassword,
          onToggle: () {
            setState(() {
              _obscureConfirmPassword =
              !_obscureConfirmPassword;
            });
          },
        ),

        const SizedBox(height: 24),

        _infoStrip(
          Icons.verified_user_outlined,
          "We'll send a verification link to your email.",
        ),
      ],
    );
  }

  // ============================================================
  // REGISTER BUTTON
  // ============================================================

  Widget _buildRegisterButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        12,
        24,
        28,
      ),
      decoration: BoxDecoration(
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _isLoading ? null : _register,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: yellow,
            borderRadius:
            BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: yellow.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(
                "Create Account",
                style: TextStyle(
                  color: navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: navy,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: txtDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          decoration: BoxDecoration(
            color: grey,
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: greyBdr,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText:
            isPassword ? obscure : false,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: txtDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              hintText: hint,
              hintStyle: const TextStyle(
                color: txtHint,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                icon,
                color: yellow,
                size: 20,
              ),
              suffixIcon: isPassword
                  ? GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons
                      .visibility_off_outlined,
                  color: txtHint,
                  size: 18,
                ),
              )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  Widget _infoStrip(
      IconData icon,
      String message,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: grey,
        borderRadius:
        BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: yellow,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: txtMed,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: txtMed,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DECOR
  // ============================================================

  Widget _decorCircle(
      double size,
      Color color,
      ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}