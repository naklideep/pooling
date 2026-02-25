import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import 'live_ride_tracking_page.dart';
import 'rating_dialog.dart';

class RideActivePage extends StatefulWidget {
  final String rideId;
  final String userId;
  final bool isDriver;

  const RideActivePage({
    required this.rideId,
    required this.userId,
    required this.isDriver,
    super.key,
  });

  @override
  State<RideActivePage> createState() => _RideActivePageState();
}

class _RideActivePageState extends State<RideActivePage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isVerified = false;
  bool _isVerifying = false;
  String? _rideCode;
  String? _errorText;
  Map<String, dynamic> _rideData = {};

  final List<TextEditingController> _pinControllers =
  List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _unlockController;
  late Animation<double> _unlockAnim;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _unlockAnim = CurvedAnimation(
      parent: _unlockController,
      curve: Curves.elasticOut,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeController);

    _initRide();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _unlockController.dispose();
    _shakeController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Init: generate or fetch code ───────────────────────────────────────────
  Future<void> _initRide() async {
    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (!doc.exists || !mounted) return;
    final data = doc.data()!;
    setState(() => _rideData = data);

    // Check if already verified
    if (data['rideStarted'] == true) {
      setState(() => _isVerified = true);
      _unlockController.forward();
      return;
    }

    // Driver generates code if not already set
    if (widget.isDriver && data['rideCode'] == null) {
      final code = _generateCode();
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({'rideCode': code});
      setState(() => _rideCode = code);
    } else {
      setState(() => _rideCode = data['rideCode']);
    }
  }

  String _generateCode() {
    final rand = Random.secure();
    return (1000 + rand.nextInt(9000)).toString();
  }

  // ── Verify code (rider submits) ────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final entered = _pinControllers.map((c) => c.text).join();
    if (entered.length < 4) return;

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    final storedCode = doc.data()?['rideCode']?.toString();

    if (storedCode == entered) {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({'rideStarted': true, 'status': 'in_progress'});

      HapticFeedback.heavyImpact();
      setState(() {
        _isVerified = true;
        _isVerifying = false;
      });
      _unlockController.forward();
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      for (final c in _pinControllers) {
        c.clear();
      }
      _pinFocusNodes[0].requestFocus();
      setState(() {
        _errorText = 'Wrong code. Ask your driver again.';
        _isVerifying = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double _getDouble(dynamic val, {bool isLat = true}) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    if (val is GeoPoint) return isLat ? val.latitude : val.longitude;
    return 0.0;
  }

  void _openTracking() {
    final startLat = _getDouble(_rideData['from_lat']);
    final startLng = _getDouble(_rideData['from_lng'], isLat: false);
    final destLat = _getDouble(_rideData['to_lat']);
    final destLng = _getDouble(_rideData['to_lng'], isLat: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRideTrackingPage(
          rideId: widget.rideId,
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          isDriver: widget.isDriver,
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(rideId: widget.rideId)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3C72),
                  Color(0xFF2A5298),
                  Color(0xFF7E22CE),
                ],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            right: -80,
            child: _decorCircle(260, 0.08),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _decorCircle(340, 0.06),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rides')
                        .doc(widget.rideId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                        snapshot.data!.data() as Map<String, dynamic>;
                        if (data['rideStarted'] == true && !_isVerified) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => _isVerified = true);
                            _unlockController.forward();
                          });
                        }
                        _rideData = data;
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Column(
                          children: [
                            _buildRouteCard(),
                            const SizedBox(height: 20),
                            _isVerified
                                ? _buildUnlockedPanel()
                                : widget.isDriver
                                ? _buildDriverCodePanel()
                                : _buildRiderPinPanel(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _glassButton(
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          _glassButton(
            child: const Icon(Icons.directions_car,
                color: Colors.white, size: 20),
            onTap: null,
          ),
          const SizedBox(width: 12),
          const Text(
            'Active Ride',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          if (_isVerified)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_open_rounded,
                      size: 14, color: Colors.greenAccent),
                  SizedBox(width: 5),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Route summary card ─────────────────────────────────────────────────────
  Widget _buildRouteCard() {
    return _glassCard(
      child: Column(
        children: [
          _routeRow(
            icon: Icons.trip_origin,
            iconColor: Colors.greenAccent,
            bgColor: Colors.green,
            label: 'From',
            value: _rideData['from'] ?? '—',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 28,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
          _routeRow(
            icon: Icons.location_on,
            iconColor: Colors.redAccent,
            bgColor: Colors.red,
            label: 'To',
            value: _rideData['to'] ?? '—',
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Driver: show the code ──────────────────────────────────────────────────
  Widget _buildDriverCodePanel() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded,
                    color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your Ride Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your rider to start the ride.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.65), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Pulsing code display
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 360 ? 18 : 36,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _rideCode ?? '----',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width < 360 ? 38 : 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Copy button
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _rideCode ?? ''));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Code copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.amber.shade700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Copy Code',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _waitingIndicator('Waiting for rider to enter the code…'),
        ],
      ),
    );
  }

  // ── Rider: enter the code ─────────────────────────────────────────────────
  Widget _buildRiderPinPanel() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final shakeOffset =
            sin(_shakeAnim.value * pi * 6) * 10 * (1 - _shakeAnim.value);
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: _glassCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Colors.lightBlueAccent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enter Ride Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your driver for the 4-digit code to begin the ride.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 28),

            // PIN boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _buildPinBox(i)),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isVerifying
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
                    : const Text(
                  'Verify & Start Ride',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinBox(int index) {
    final boxSize = (MediaQuery.of(context).size.width - 120) / 4;
    return Container(
      width: boxSize,
      height: boxSize + 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _pinFocusNodes[index].hasFocus
              ? Colors.lightBlueAccent
              : Colors.white.withOpacity(0.25),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _pinFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.isNotEmpty && index < 3) {
            _pinFocusNodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _pinFocusNodes[index - 1].requestFocus();
          }
          // Auto verify when all filled
          if (index == 3 && val.isNotEmpty) {
            final all = _pinControllers.map((c) => c.text).join();
            if (all.length == 4) _verifyCode();
          }
          setState(() {});
        },
      ),
    );
  }

  // ── Unlocked panel (post-verification) ────────────────────────────────────
  Widget _buildUnlockedPanel() {
    return ScaleTransition(
      scale: _unlockAnim,
      child: _glassCard(
        borderColor: Colors.greenAccent.withOpacity(0.4),
        child: Column(
          children: [
            // Success header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      color: Colors.greenAccent, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ride Started! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'All features are now unlocked.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RIDE ACTIONS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: (MediaQuery.of(context).size.width - 120) / 2 / 52,
              children: [
                _buildActionTile(
                  icon: Icons.map_rounded,
                  label: 'Track Ride',
                  gradient: const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  onTap: _openTracking,
                ),
                _buildActionTile(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  onTap: _openChat,
                ),
                _buildActionTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Done',
                  gradient: const [Color(0xFF059669), Color(0xFF10B981)],
                  onTap: () => _showDoneDialog(),
                ),
                _buildActionTile(
                  icon: Icons.cancel_rounded,
                  label: 'Cancel',
                  gradient: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                  onTap: () => _showCancelDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  Future<void> _showDoneDialog() async {
    final confirmed = await _confirmSheet(
      icon: Icons.check_circle_outline,
      iconColor: Colors.greenAccent,
      bgColor: Colors.green,
      title: 'Complete Ride?',
      subtitle:
      'Both parties must confirm to fully complete the ride.',
      confirmLabel: 'Yes, Complete',
      confirmColor: Colors.greenAccent,
      confirmTextColor: const Color(0xFF1E3C72),
    );
    if (confirmed != true || !mounted) return;

    final rideRef = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId);

    await rideRef.update({
      widget.isDriver ? 'posterCompleted' : 'accepterCompleted': true,
    });

    // Check if both completed → show rating dialog
    final doc = await rideRef.get();
    final data = doc.data()!;
    final bothDone = (data['posterCompleted'] ?? false) &&
        (data['accepterCompleted'] ?? false);

    if (bothDone) {
      await rideRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    // Show rating for the other party
    final rateUserId = widget.isDriver
        ? (data['acceptedBy'] ?? (data['acceptedByList'] as List?)?.first)
        : data['riderId'];
    final rateUserName = widget.isDriver
        ? (data['acceptedByName'] ?? 'Your Rider')
        : (data['postedByName'] ?? 'Your Driver');

    if (rateUserId != null && mounted) {
      await showRatingDialog(
        context: context,
        ratedUserId: rateUserId,
        ratedUserName: rateUserName,
        rideId: widget.rideId,
        currentUserId: widget.userId,
      );
    }

    if (mounted) {
      _showSnack(
        bothDone
            ? '✅ Ride completed!'
            : 'Marked as complete! Waiting for the other party…',
        Colors.green,
      );
    }
  }

  Future<void> _showCancelDialog() async {
    final confirmed = await _confirmSheet(
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      bgColor: Colors.red,
      title: 'Cancel Ride?',
      subtitle: 'Both parties must confirm to fully cancel the ride.',
      confirmLabel: 'Yes, Cancel',
      confirmColor: Colors.redAccent,
      confirmTextColor: Colors.white,
    );
    if (confirmed != true || !mounted) return;
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .update({
      widget.isDriver ? 'posterCancelled' : 'accepterCancelled': true,
    });
    _showSnack('Cancellation requested.', Colors.red);
  }

  Future<bool?> _confirmSheet({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color confirmColor,
    required Color confirmTextColor,
  }) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3C72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            CircleAvatar(
              radius: 28,
              backgroundColor: bgColor.withOpacity(0.2),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 14,
                    height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: confirmTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmLabel,
                        style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _glassCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _glassButton({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border:
          Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white.withOpacity(opacity), Colors.transparent],
        ),
      ),
    );
  }

  Widget _waitingIndicator(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13)),
      ],
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}