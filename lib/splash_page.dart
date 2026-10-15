import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/login_page.dart';
import 'features/main_shell.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/onboarding_page.dart';

// NOTE: Admin is currently routed by hardcoded email — see audit for Custom Claims upgrade plan.
const String adminEmail = "chaudharideep1106@gmail.com";

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {

  // ── Palette ──────────────────────────────────
  static const navy    = Color(0xFF0D1B3E);
  static const yellow  = Color(0xFFFFCC00);
  static const white   = Color(0xFFFFFFFF);

  // ── Controllers ──────────────────────────────
  late AnimationController _bgAnim;
  late AnimationController _badgeAnim;
  late AnimationController _textAnim;
  late AnimationController _loaderAnim;
  late AnimationController _carDriveAnim;
  late AnimationController _pulseAnim;

  // badge
  late Animation<double> _badgeScale;
  late Animation<double> _badgeFade;
  late Animation<double> _badgeRotate;

  // car drive
  late Animation<Offset> _carSlide;
  late Animation<double>  _carFade;

  // text lines
  late Animation<Offset> _line1Slide;
  late Animation<double>  _line1Fade;
  late Animation<Offset> _line2Slide;
  late Animation<double>  _line2Fade;
  late Animation<Offset> _line3Slide;
  late Animation<double>  _line3Fade;

  // loader
  late Animation<double> _loaderFade;

  // pulse ring
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // bg orb
  late Animation<double> _bgOrb;

  @override
  void initState() {
    super.initState();

    _bgAnim       = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _badgeAnim    = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _carDriveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textAnim     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _loaderAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseAnim    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

    _bgOrb = Tween<double>(begin: 0.0, end: 1.0).animate(_bgAnim);

    _badgeScale  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _badgeAnim, curve: Curves.easeOutBack));
    _badgeFade   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _badgeAnim, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _badgeRotate = Tween<double>(begin: -0.15, end: 0.0).animate(
        CurvedAnimation(parent: _badgeAnim, curve: Curves.easeOutCubic));

    _carSlide = Tween<Offset>(begin: const Offset(-1.5, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _carDriveAnim, curve: Curves.easeOutCubic));
    _carFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _carDriveAnim, curve: const Interval(0.0, 0.4)));

    _line1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _line1Fade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.0, 0.5)));

    _line2Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic)));
    _line2Fade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.2, 0.65)));

    _line3Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));
    _line3Fade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAnim, curve: const Interval(0.4, 0.8)));

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _loaderAnim, curve: Curves.easeIn));

    _pulseScale   = Tween<double>(begin: 1.0, end: 2.2).animate(
        CurvedAnimation(parent: _pulseAnim, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _pulseAnim, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _badgeAnim.forward();

    await Future.delayed(const Duration(milliseconds: 350));
    _carDriveAnim.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _textAnim.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _loaderAnim.forward();

    // Give the animations time to play before session check
    await Future.delayed(const Duration(milliseconds: 600));
    _checkSession();
  }

  // ── Session check ─────────────────────────────
  Future<void> _checkSession() async {
    // 1. Show onboarding on first launch
    final seen = await OnboardingPage.hasSeenOnboarding();
    if (!seen) {
      _goTo(const OnboardingPage());
      return;
    }

    // 2. Let Firebase fully hydrate
    await Future.delayed(const Duration(milliseconds: 500));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !user.emailVerified) {
      _goTo(LoginPage());
      return;
    }

    // 3. Fetch Firestore doc to check ban + role
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['isBanned'] == true) {
        await FirebaseAuth.instance.signOut();
        _goTo(LoginPage());
        return;
      }

      final isAdmin = user.email == adminEmail ||
          (doc.exists && doc.data()?['role'] == 'admin');

      _goTo(isAdmin ? const AdminDashboardPage() : const MainShell());

    } catch (_) {
      await FirebaseAuth.instance.signOut();
      _goTo(LoginPage());
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _badgeAnim.dispose();
    _carDriveAnim.dispose();
    _textAnim.dispose();
    _loaderAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: navy,
      body: Stack(children: [

        // ── Animated background ─────────────────
        _buildBackground(size),

        // ── Content ─────────────────────────────
        SafeArea(
          child: Column(children: [

            const Spacer(flex: 2),

            // Badge + pulse ring
            _buildBadgeSection(),

            const SizedBox(height: 36),

            // Car driving in
            _buildCarRow(),

            const SizedBox(height: 40),

            // Text block
            _buildTextBlock(),

            const Spacer(flex: 3),

            // Bottom loader
            _buildLoader(),

            const SizedBox(height: 48),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // BACKGROUND
  // ─────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgOrb,
      builder: (_, __) {
        final t = _bgOrb.value;
        return Stack(children: [
          CustomPaint(painter: _GridPainter(), size: Size.infinite),
          Positioned(
            top: -40 + (t * 20), right: -60 + (t * 10),
            child: _glowOrb(320, yellow.withOpacity(0.07 + t * 0.04)),
          ),
          Positioned(
            bottom: 100 + (t * 15), left: -70,
            child: _glowOrb(220, yellow.withOpacity(0.05 + t * 0.03)),
          ),
          Positioned(
            top: size.height * 0.35, left: size.width * 0.3,
            child: _glowOrb(160, yellow.withOpacity(0.04 + t * 0.02)),
          ),
          Positioned(
            top: 120 + (t * 8), right: 60,
            child: _glowOrb(70, yellow.withOpacity(0.14)),
          ),
        ]);
      },
    );
  }

  Widget _glowOrb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  // ─────────────────────────────────────────────
  // BADGE + PULSE RING
  // ─────────────────────────────────────────────
  Widget _buildBadgeSection() {
    return SizedBox(
      width: 120, height: 120,
      child: Stack(alignment: Alignment.center, children: [

        // Pulse ring 1
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseScale.value,
            child: Opacity(
              opacity: _pulseOpacity.value,
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: yellow, width: 2),
                ),
              ),
            ),
          ),
        ),

        // Pulse ring 2 (offset phase)
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) {
            final t = (_pulseAnim.value + 0.4) % 1.0;
            return Transform.scale(
              scale: 1.0 + t * 1.2,
              child: Opacity(
                opacity: (1.0 - t) * 0.35,
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: yellow, width: 1.5),
                  ),
                ),
              ),
            );
          },
        ),

        // Badge
        ScaleTransition(
          scale: _badgeScale,
          child: FadeTransition(
            opacity: _badgeFade,
            child: AnimatedBuilder(
              animation: _badgeRotate,
              builder: (_, child) => Transform.rotate(
                angle: _badgeRotate.value, child: child,
              ),
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: yellow,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: yellow.withOpacity(0.55), blurRadius: 32, spreadRadius: 4, offset: const Offset(0, 8)),
                    BoxShadow(color: yellow.withOpacity(0.2),  blurRadius: 60, spreadRadius: 10),
                  ],
                ),
                child: Stack(children: [
                  Positioned.fill(child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [white.withOpacity(0.28), Colors.transparent],
                      ),
                    ),
                  )),
                  const Center(
                    child: Icon(Icons.directions_car_rounded, color: navy, size: 46),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // CAR DRIVING IN
  // ─────────────────────────────────────────────
  Widget _buildCarRow() {
    return SlideTransition(
      position: _carSlide,
      child: FadeTransition(
        opacity: _carFade,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(children: [
            Expanded(
              child: Row(children: List.generate(8, (i) => Expanded(
                child: Container(
                  height: 2, margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: yellow.withOpacity(0.25),
                ),
              ))),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: yellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: yellow.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.directions_car_filled_rounded, color: yellow, size: 18),
                const SizedBox(width: 6),
                Text("On the way",
                    style: TextStyle(color: yellow.withOpacity(0.8),
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TEXT BLOCK
  // ─────────────────────────────────────────────
  Widget _buildTextBlock() {
    return Column(children: [

      SlideTransition(
        position: _line1Slide,
        child: FadeTransition(
          opacity: _line1Fade,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded, color: navy, size: 12),
              SizedBox(width: 4),
              Text("CARPOOL TOGETHER", style: TextStyle(
                  color: navy, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 1.6)),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 16),

      SlideTransition(
        position: _line2Slide,
        child: FadeTransition(
          opacity: _line2Fade,
          child: const Text(
            "Pooling",
            style: TextStyle(
              color: white, fontSize: 52,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5, height: 1.0,
            ),
          ),
        ),
      ),

      const SizedBox(height: 10),

      SlideTransition(
        position: _line3Slide,
        child: FadeTransition(
          opacity: _line3Fade,
          child: Text(
            "Better rides, together.",
            style: TextStyle(
              color: white.withValues(alpha: 0.4),
              fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  // LOADER
  // ─────────────────────────────────────────────
  Widget _buildLoader() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(yellow),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text("Loading your account...",
            style: TextStyle(
                color: white.withOpacity(0.3),
                fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// GRID PAINTER
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