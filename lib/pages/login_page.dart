import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'registration_page.dart';
import 'admin_dashboard_page.dart';
import 'onboarding_page.dart';

const String adminEmail = "chaudharideep1106@gmail.com";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscure  = true;
  bool _loading  = false;

  final _auth = FirebaseAuth.instance;

  // ── Palette (matches your app) ──────────────
  static const navy    = Color(0xFF0D1B3E);
  static const navyMid = Color(0xFF1A2F5E);
  static const yellow  = Color(0xFFFFCC00);
  static const white   = Color(0xFFFFFFFF);
  static const grey    = Color(0xFFF0F2F8);
  static const greyBdr = Color(0xFFDDE0EE);
  static const txtDark = Color(0xFF0D1B3E);
  static const txtMed  = Color(0xFF6B7280);
  static const txtHint = Color(0xFFB0B8D0);
  static const red     = Color(0xFFEF4444);
  static const green   = Color(0xFF16A34A);

  // ── Animations ───────────────────────────────
  late AnimationController _heroAnim;
  late AnimationController _cardAnim;
  late AnimationController _pulseAnim;

  late Animation<double>  _heroScale;
  late Animation<double>  _heroFade;
  late Animation<Offset>  _cardSlide;
  late Animation<double>  _cardFade;
  late Animation<double>  _pulse;

  @override
  void initState() {
    super.initState();

    _heroAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _heroScale = Tween<double>(begin: 0.82, end: 1.0).animate(
        CurvedAnimation(parent: _heroAnim, curve: Curves.easeOutBack));
    _heroFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroAnim, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));

    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));
    _cardFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardAnim, curve: Curves.easeIn));

    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      _heroAnim.forward();
      Future.delayed(const Duration(milliseconds: 220), () => _cardAnim.forward());
    });
  }

  // ── Login ─────────────────────────────────────
  void _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) { _snack("Fill all fields", true); return; }

    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithEmailAndPassword(email: email, password: pass);

      if (!user.user!.emailVerified) {
        await _auth.signOut();
        _snack("Verify your email first", true);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.user!.uid).get();

      if (doc.exists && doc.data()?['isBanned'] == true) {
        await _auth.signOut();
        _snack("Your account has been banned", true);
        return;
      }

      final isAdmin = user.user!.email == adminEmail ||
          (doc.data()?['role'] == 'admin');

      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => isAdmin ? const AdminDashboardPage() : DashboardPage(),
      ));

    } catch (e) {
      _snack("Invalid email or password", true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: isError ? white : navy, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(
            color: isError ? white : navy,
            fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: isError ? red : yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      elevation: 8,
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _heroAnim.dispose();
    _cardAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [

        // ── Background decorations ──────────────
        _buildBgDecor(),

        SafeArea(
          child: Column(children: [

            // ── HERO ────────────────────────────
            ScaleTransition(
              scale: _heroScale,
              child: FadeTransition(
                opacity: _heroFade,
                child: _buildHero(),
              ),
            ),

            // ── LIVE CHIP STRIP ─────────────────
            FadeTransition(
              opacity: _heroFade,
              child: _buildChipStrip(),
            ),

            // ── FORM CARD ───────────────────────
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

        // ── Loading overlay ─────────────────────
        if (_loading) _buildLoadingOverlay(),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // BACKGROUND
  // ─────────────────────────────────────────────
  Widget _buildBgDecor() {
    return Stack(children: [
      // Grid pattern
      CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
      // Glow orbs
      Positioned(top: -30, right: -60,
          child: _glowOrb(280, yellow.withOpacity(0.09))),
      Positioned(top: 160, right: 30,
          child: _glowOrb(90, yellow.withOpacity(0.13))),
      Positioned(bottom: 220, left: -50,
          child: _glowOrb(180, yellow.withOpacity(0.07))),
      Positioned(top: 100, left: 20,
          child: _glowOrb(50, yellow.withOpacity(0.08))),
    ]);
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size, height: size,
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

        // Left: text
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            // Yellow pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: navy, size: 12),
                SizedBox(width: 4),
                Text("CAMPUS RIDES", style: TextStyle(
                    color: navy, fontSize: 9,
                    fontWeight: FontWeight.w900, letterSpacing: 1.4)),
              ]),
            ),
            const SizedBox(height: 12),
            // Title
            RichText(
              text: const TextSpan(
                style: TextStyle(color: white, fontSize: 38,
                    fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.8),
                children: [
                  TextSpan(text: "Welcome\n"),
                  TextSpan(text: "Back"),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text("Login to continue your ride",
                style: TextStyle(color: white.withOpacity(0.45),
                    fontSize: 13, fontWeight: FontWeight.w400)),
          ]),
        ),

        const SizedBox(width: 20),

        // Right: Car badge
        _buildCarBadge(),
      ]),
    );
  }

  Widget _buildCarBadge() {
    return Container(
      width: 76, height: 76,
      decoration: BoxDecoration(
        color: yellow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: yellow.withOpacity(0.5), blurRadius: 28, spreadRadius: 2, offset: const Offset(0, 8)),
          BoxShadow(color: yellow.withOpacity(0.2), blurRadius: 60, spreadRadius: 10),
        ],
      ),
      child: Stack(children: [
        // Shine overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [white.withOpacity(0.25), Colors.transparent],
              ),
            ),
          ),
        ),
        const Center(
          child: Icon(Icons.directions_car_rounded, color: navy, size: 38),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // CHIP STRIP (live indicator)
  // ─────────────────────────────────────────────
  Widget _buildChipStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      child: Row(children: [
        _liveChip(),
        const SizedBox(width: 10),
        _infoChip(Icons.location_city_outlined, "Tarsadia University"),
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
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green,
                boxShadow: [BoxShadow(color: green.withOpacity(0.6), blurRadius: 4, spreadRadius: 1)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text("Live Rides Active",
            style: TextStyle(color: white.withOpacity(0.65),
                fontSize: 11, fontWeight: FontWeight.w600)),
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
        Text(label, style: TextStyle(color: white.withOpacity(0.55),
            fontSize: 11, fontWeight: FontWeight.w500)),
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

          // Card top row: title + secure badge
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Sign In",
                    style: TextStyle(color: txtDark, fontSize: 24,
                        fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text("Access your GharTak account",
                    style: TextStyle(color: txtMed, fontSize: 12)),
              ]),
            ),
            // Secure badge
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
                Text("SECURE", style: TextStyle(
                    color: txtMed, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ]),
            ),
          ]),

          const SizedBox(height: 28),

          // Email
          _inputField(
            ctrl: _emailCtrl,
            label: "Email Address",
            hint: "sheth@example.com",
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          // Password
          _inputField(
            ctrl: _passCtrl,
            label: "Password",
            hint: "Min. 6 characters",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),

          const SizedBox(height: 10),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final email = _emailCtrl.text.trim();

                if (email.isEmpty) {
                  _snack("Enter your email first", true);
                  return;
                }

                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  _snack("Password reset link sent to your email", false);
                } catch (e) {
                  _snack("Failed to send reset email", true);
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text("Forgot password?",
                  style: TextStyle(color: navy, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 24),

          // LOGIN BUTTON
          GestureDetector(
            onTap: _loading ? null : _login,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: yellow.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6)),
                  BoxShadow(color: yellow.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                // Shine
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.centerRight,
                        colors: [white.withOpacity(0.22), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _loading ? "Signing in..." : "Login",
                    style: const TextStyle(color: navy, fontSize: 16,
                        fontWeight: FontWeight.w900, letterSpacing: 0.3),
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

          // Divider
          Row(children: [
            Expanded(child: Divider(color: greyBdr, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text("OR", style: TextStyle(color: txtHint,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
            Expanded(child: Divider(color: greyBdr, thickness: 1)),
          ]),

          const SizedBox(height: 22),

          // REGISTER BUTTON
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => RegistrationPage())),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: grey,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: greyBdr, width: 1.5),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.person_add_alt_1_outlined, color: navy, size: 18),
                SizedBox(width: 10),
                Text("Create New Account",
                    style: TextStyle(color: navy, fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Info strip
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
                child: Text("Your data is encrypted and never shared",
                    style: TextStyle(color: txtMed, fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INPUT FIELD
  // ─────────────────────────────────────────────
  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: txtDark, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: greyBdr, width: 1.5),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: isPassword ? _obscure : false,
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
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: txtHint, size: 18,
              ),
            )
                : null,
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // LOADING OVERLAY
  // ─────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: yellow, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.directions_car_rounded, color: navy, size: 28),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
            const SizedBox(height: 14),
            const Text("Signing you in...",
                style: TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GRID PAINTER (subtle background texture)
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