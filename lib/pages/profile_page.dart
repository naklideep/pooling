import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool _signingOut = false;
  Widget _buildAvatar() {
    final photoUrl = userData?['photoUrl'] as String?;

    final hasPhoto =
        photoUrl != null && photoUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: 46,
      backgroundColor: yellow,
      backgroundImage:
      hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
        _getInitials(userData?['name']),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: navy,
          letterSpacing: -1,
        ),
      ),
    );
  }
  // UPI editing state
  bool _editingUpi = false;
  bool _savingUpi = false;
  final TextEditingController _upiController = TextEditingController();

  // ── Palette ──────────────────────────────────
  static const navy    = Color(0xFF0D1B3E);
  static const yellow  = Color(0xFFFFCC00);
  static const white   = Color(0xFFFFFFFF);
  static const grey    = Color(0xFFF0F2F8);
  static const greyBdr = Color(0xFFDDE0EE);
  static const txtDark = Color(0xFF0D1B3E);
  static const txtMed  = Color(0xFF6B7280);
  static const txtHint = Color(0xFF9CA3AF);
  static const red     = Color(0xFFEF4444);
  static const bg      = Color(0xFFF0F2F8);

  // ── Animations ───────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _heroCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _cardsCtrl;

  late Animation<double> _fadein;
  late Animation<double> _avatarScale;
  late Animation<double> _avatarFade;
  late Animation<double> _pulse;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;

  @override
  void initState() {
    super.initState();

    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _heroCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _cardsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _fadein      = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutBack));
    _avatarFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6)));
    _pulse       = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _cardsFade   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut));
    _cardsSlide  = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOutCubic));

    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _heroCtrl.dispose();
    _pulseCtrl.dispose();
    _cardsCtrl.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            userData = data;
            isLoading = false;
            // Pre-fill UPI controller with saved value
            _upiController.text = data['upiId'] ?? '';
          });
          _fadeCtrl.forward();
          await Future.delayed(const Duration(milliseconds: 100));
          _heroCtrl.forward();
          await Future.delayed(const Duration(milliseconds: 300));
          _cardsCtrl.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _snack('Failed to load profile: $e', isError: true);
      }
    }
  }

  // ── Save UPI to Firestore ────────────────────
  Future<void> _saveUpi() async {
    final upiId = _upiController.text.trim();

    // Basic UPI validation: must contain @
    if (upiId.isNotEmpty && !upiId.contains('@')) {
      _snack('Enter a valid UPI ID (e.g. name@upi)', isError: true);
      return;
    }

    setState(() => _savingUpi = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'upiId': upiId});

        setState(() {
          userData = {...?userData, 'upiId': upiId};
          _editingUpi = false;
        });
        _snack(upiId.isEmpty ? 'UPI ID removed' : 'UPI ID saved ✓');
      }
    } catch (e) {
      _snack('Failed to save UPI ID', isError: true);
    } finally {
      if (mounted) setState(() => _savingUpi = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignOutSheet(),
    );
    if (confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await _auth.signOut();
      // ✅ ADD THIS — same as dashboard logout
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _signingOut = false);
        _snack('Sign-out failed: $e', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: isError ? white : navy,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
      backgroundColor: isError ? red : yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }
  String _formatDob(dynamic dob) {
    if (dob == null) return '—';

    try {
      DateTime date;

      if (dob is Timestamp) {
        date = dob.toDate();
      } else if (dob is DateTime) {
        date = dob;
      } else {
        return '—';
      }

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return '—';
    }
  }
  // ── BUILD ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bg,
        body: isLoading
            ? _buildLoader()
            : FadeTransition(
          opacity: _fadein,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverHeader(),
              _buildSliverBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: navy,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: white.withOpacity(0.15)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: white, size: 16),
        ),
      ),
      title: const Text('My Profile',
          style: TextStyle(
              color: white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2)),
      centerTitle: true,
    );
  }

  Widget _buildProfileHeroCard() {
    return ScaleTransition(
      scale: _avatarScale,
      child: FadeTransition(
        opacity: _avatarFade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: navy.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
              BoxShadow(
                  color: yellow.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 4),
            ],
          ),
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            Positioned(top: -20, right: -20,
                child: _glowOrb(140, yellow.withOpacity(0.10))),
            Positioned(bottom: -10, left: -10,
                child: _glowOrb(90, yellow.withOpacity(0.07))),

            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Avatar
                  SizedBox(
                    width: 120, height: 120,
                    child: Stack(alignment: Alignment.center, children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Container(
                          width: 116, height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: yellow.withOpacity(_pulse.value * 0.45),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 102, height: 102,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: yellow, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: yellow.withOpacity(0.45),
                                blurRadius: 24,
                                spreadRadius: 2),
                          ],
                        ),
                      ),
                      _buildAvatar(),
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                            border: Border.all(color: navy, width: 2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: white, size: 13),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    userData?['name'] ?? 'Student',
                    style: const TextStyle(
                        color: white, fontSize: 22,
                        fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),


                  const SizedBox(height: 12),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSliverBody() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 28, 20, 24 + bottomPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          SlideTransition(
            position: _cardsSlide,
            child: FadeTransition(
              opacity: _cardsFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _buildProfileHeroCard(),

                  const SizedBox(height: 28),
                  _sectionLabel('Personal Information'),
                  const SizedBox(height: 12),

                  _infoCard(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: userData?['name'] ?? '—',
                    accent: navy,
                  ),
                  _infoCard(
                    icon: Icons.alternate_email_rounded,
                    label: 'Email Address',
                    value: userData?['email'] ?? '—',
                    accent: const Color(0xFF10B981),
                  ),
                  _infoCard(
                    icon: Icons.cake_outlined,
                    label: 'Date of Birth',
                    value: _formatDob(userData?['dob']),
                    accent: const Color(0xFF8B5CF6),
                  ),
                  _infoCard(
                    icon: Icons.wc_rounded,
                    label: 'Gender',
                    value: userData?['gender']?.toString() ?? '—',
                    accent: const Color(0xFFEC4899),
                  ),

                  _infoCard(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member Since',
                    value: userData?['createdAt'] != null
                        ? (userData!['createdAt'] as dynamic)
                        .toDate()
                        .toString()
                        .split(' ')[0]
                        : '—',
                    accent: const Color(0xFFF59E0B),
                  ),

                  const SizedBox(height: 28),

                  // ── 🔥 UPI ID SECTION ──────────────
                  _sectionLabel('Payment'),
                  const SizedBox(height: 12),
                  _buildUpiCard(),

                  const SizedBox(height: 28),
                  _sectionLabel('Account'),
                  const SizedBox(height: 12),

                  _statusCard(),

                  const SizedBox(height: 28),

                  _buildSignOutButton(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── UPI CARD ─────────────────────────────────
  Widget _buildUpiCard() {
    final savedUpi = userData?['upiId'] as String?;
    final hasUpi = savedUpi != null && savedUpi.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UPI ID',
                        style: TextStyle(
                            fontSize: 11, color: txtHint,
                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Text(
                      hasUpi ? savedUpi! : 'Not set — riders can\'t pay you',
                      style: TextStyle(
                          fontSize: 14,
                          color: hasUpi ? txtDark : txtHint,
                          fontWeight: hasUpi ? FontWeight.w700 : FontWeight.w500,
                          fontStyle: hasUpi ? FontStyle.normal : FontStyle.italic),
                    ),
                  ],
                ),
              ),
              // Edit / Done button
              GestureDetector(
                onTap: () {
                  if (_editingUpi) {
                    _saveUpi();
                  } else {
                    setState(() => _editingUpi = true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _editingUpi
                        ? const Color(0xFF16A34A)
                        : navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _savingUpi
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: white))
                      : Text(
                    _editingUpi ? 'Save' : 'Edit',
                    style: TextStyle(
                        color: _editingUpi ? white : navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 12),
                  ),
                ),
              ),
            ]),

            // Editable text field — only shown when editing
            if (_editingUpi) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _upiController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                    color: txtDark, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'yourname@upi',
                  hintStyle: const TextStyle(color: txtHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.tag_rounded,
                      color: Color(0xFF6366F1), size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF6366F1), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _saveUpi(),
              ),
              const SizedBox(height: 8),
              Text(
                'This is shown to riders when paying you after a ride.',
                style: TextStyle(
                    color: txtHint, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: value));
            HapticFeedback.lightImpact();
            _snack('$label copied');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: txtHint,
                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 15, color: txtDark,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final isVerified = _auth.currentUser?.emailVerified ?? false;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            color: navy,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Account',
                style: TextStyle(
                  fontSize: 14,
                  color: txtDark,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                'RideBuddy Community Member',
                style: TextStyle(
                  fontSize: 11,
                  color: txtMed,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isVerified
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isVerified ? Icons.verified_rounded : Icons.pending_rounded,
              color: isVerified
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD97706),
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              isVerified ? 'Verified' : 'Pending',
              style: TextStyle(
                color: isVerified
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
                fontSize: 10, fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _signingOut ? null : _signOut,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: red.withOpacity(0.25), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_signingOut)
            const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: red))
          else
            const Icon(Icons.logout_rounded, color: red, size: 20),
          const SizedBox(width: 10),
          Text(
            _signingOut ? 'Signing Out…' : 'Sign Out',
            style: const TextStyle(
                color: red, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: txtHint, letterSpacing: 1.6),
  );

  Widget _buildLoader() => const Center(
    child: CircularProgressIndicator(color: navy, strokeWidth: 2.5),
  );

  Widget _glowOrb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

// ─────────────────────────────────────────────
// SIGN OUT SHEET
// ─────────────────────────────────────────────
class _SignOutSheet extends StatelessWidget {
  static const navy  = Color(0xFF0D1B3E);
  static const red   = Color(0xFFEF4444);
  static const white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 24),
          decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, color: red, size: 28),
        ),
        const SizedBox(height: 18),
        const Text('Sign Out?',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8),
        Text(
          "You'll need to log in again to access your account.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.grey.shade500, height: 1.5),
        ),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDE0EE)),
                ),
                child: Center(
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: red,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: red.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Text('Sign Out',
                      style: TextStyle(
                          color: white,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ),
          ),
        ]),
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
      ..color = const Color(0xFFFFCC00).withOpacity(0.035)
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