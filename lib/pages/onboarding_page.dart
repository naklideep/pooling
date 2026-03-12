import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart'; // adjust import path as needed

/// Call this once, e.g. in main() or SplashPage, to decide whether to show onboarding.
/// Usage inside SplashPage._checkSession():
///   final seen = await OnboardingPage.hasSeenOnboarding();
///   if (!seen) { _goTo(const OnboardingPage()); return; }
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const _prefKey = 'onboarding_complete';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

// ── slide data ──────────────────────────────────────────────────────────────

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}

const _slides = [
  _Slide(
    icon: Icons.directions_car_rounded,
    title: "Ride at Your\nDoorstep",
    subtitle:
    "Book a reliable cab in seconds.\nGharTak gets you home — fast, safe, and comfortable.",
    gradientColors: [Color(0xFF1A2340), Color(0xFF1C2A50), Color(0xFF1E3060)],
  ),
  _Slide(
    icon: Icons.location_on_rounded,
    title: "Track Every\nMile",
    subtitle:
    "Live GPS tracking keeps you informed.\nShare your trip with loved ones for extra peace of mind.",
    gradientColors: [Color(0xFF111B33), Color(0xFF1A2340), Color(0xFF1C2A50)],
  ),
  _Slide(
    icon: Icons.shield_rounded,
    title: "Safe &\nVerified Drivers",
    subtitle:
    "All our drivers are background-checked\nand rated by the community you trust.",
    gradientColors: [Color(0xFF0D1628), Color(0xFF1A2340), Color(0xFF1E2D5A)],
  ),
];// ── state ────────────────────────────────────────────────────────────────────

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;

  late AnimationController _textController;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );
    _iconFade = CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0, 0.5, curve: Curves.easeIn),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _playAnimations();
  }

  void _playAnimations() {
    _iconController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textController.forward(from: 0);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _playAnimations();
  }

  Future<void> _finish() async {
    await OnboardingPage.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginPage(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _next() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];
    final isLast = _currentIndex == _slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── background decoration circles ──────────────────────────
              Positioned(
                top: -60,
                right: -60,
                child: _DecorCircle(size: 220, opacity: 0.07),
              ),
              Positioned(
                bottom: 140,
                left: -80,
                child: _DecorCircle(size: 280, opacity: 0.05),
              ),

              // ── skip button ────────────────────────────────────────────
              Positioned(
                top: 12,
                right: 16,
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    child: const Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              // ── page content ───────────────────────────────────────────
              Column(
                children: [
                  const SizedBox(height: 24),

                  // Branding row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_car_rounded,
                        color: const Color(0xFFFFCC00),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "GharTak",
                        style: TextStyle(
                          color: const Color(0xFFFFCC00),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // PageView (icon + text live here so they animate per page)
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _slides.length,
                      itemBuilder: (_, i) => _SlideContent(
                        slide: _slides[i],
                        iconController: _iconController,
                        iconScale: _iconScale,
                        iconFade: _iconFade,
                        textController: _textController,
                        textSlide: _textSlide,
                        textFade: _textFade,
                        isActive: i == _currentIndex,
                      ),
                    ),
                  ),

                  // ── dots ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentIndex ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? const Color(0xFFFFCC00)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── CTA button ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCC00),
                          foregroundColor: const Color(0xFF1A2340),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            isLast ? "Get Started" : "Next",
                            key: ValueKey(isLast),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: _finish,
                        child: const Text(
                          "Log In",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── slide content widget ─────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final _Slide slide;
  final AnimationController iconController;
  final Animation<double> iconScale;
  final Animation<double> iconFade;
  final AnimationController textController;
  final Animation<double> textSlide;
  final Animation<double> textFade;
  final bool isActive;

  const _SlideContent({
    required this.slide,
    required this.iconController,
    required this.iconScale,
    required this.iconFade,
    required this.textController,
    required this.textSlide,
    required this.textFade,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon in a glassy circle
        // Icon in a glassy circle
        ScaleTransition(
        scale: iconScale,
        child: FadeTransition(
          opacity: iconFade,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCC00).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFFFCC00).withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 72,
              color: const Color(0xFFFFCC00),
            ),
          ),
        ),
      ),
          const SizedBox(height: 48),

          // Title
          AnimatedBuilder(
            animation: textController,
            builder: (_, __) => Opacity(
              opacity: textFade.value,
              child: Transform.translate(
                offset: Offset(0, textSlide.value),
                child: Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Subtitle
          AnimatedBuilder(
            animation: textController,
            builder: (_, __) => Opacity(
              opacity: textFade.value,
              child: Transform.translate(
                offset: Offset(0, textSlide.value * 1.4),
                child: Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.6,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ── decorative background circle ─────────────────────────────────────────────

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFCC00).withOpacity(opacity),      ),
    );
  }
}