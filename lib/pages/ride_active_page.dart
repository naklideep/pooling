import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import 'live_ride_tracking_page.dart';
import 'rating_dialog.dart';
import 'upi_payment_page.dart';

// ── Theme ──────────────────────────────────────────────────────────────────
class T {
  static const bg        = Color(0xFFE8EAF0);
  static const surface   = Color(0xFF1C2340);
  static const card      = Color(0xFFFFFFFF);
  static const navyCard  = Color(0xFF1E2D5A);
  static const yellow    = Color(0xFFFFCC00);
  static const yellowDim = Color(0x33FFCC00);
  static const txtDark   = Color(0xFF1A1A2E);
  static const txtMed    = Color(0xFF555577);
  static const txtLight  = Color(0xFF9999BB);
  static const txtWhite  = Color(0xFFFFFFFF);
  static const green     = Color(0xFF22C55E);
  static const red       = Color(0xFFFF3D3D);
  static const border    = Color(0xFFDDDDE8);
  static const shadow    = Color(0x14000000);
}

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
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
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
    for (final c in _pinControllers) c.dispose();
    for (final f in _pinFocusNodes) f.dispose();
    super.dispose();
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> _initRide() async {
    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();
    if (!doc.exists || !mounted) return;
    final data = doc.data()!;
    setState(() => _rideData = data);

    if (data['rideStarted'] == true && data['paymentStatus'] == 'confirmed') {
      setState(() => _isVerified = true);
      _unlockController.forward();
      return;
    }

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

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final entered = _pinControllers.map((c) => c.text).join();
    if (entered.length < 4) return;

    setState(() { _isVerifying = true; _errorText = null; });

    final doc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    final storedCode = doc.data()?['rideCode']?.toString();

    if (storedCode == entered) {
      HapticFeedback.heavyImpact();

      final data = doc.data()!;
      final driverUPI = data['driverUPI'] as String?;
      final fare = (data['estimatedCost'] ?? 0).toDouble();

      if (driverUPI != null && driverUPI.isNotEmpty && fare > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpiPaymentPage(
              rideId: widget.rideId,
              amount: fare,
              driverUpiId: driverUPI,
              driverName: data['postedByName'] ?? 'Driver',
              riderId: widget.userId,
            ),
          ),
        );
      }

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({'paymentStatus': 'awaiting_confirmation'});

      setState(() => _isVerifying = false);
      _showSuccess("Payment sent! Waiting for driver to confirm...");
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      for (final c in _pinControllers) c.clear();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRideTrackingPage(
          rideId: widget.rideId,
          startLat: _getDouble(_rideData['from_lat']),
          startLng: _getDouble(_rideData['from_lng'], isLat: false),
          destLat: _getDouble(_rideData['to_lat']),
          destLng: _getDouble(_rideData['to_lng'], isLat: false),
          isDriver: widget.isDriver,
        ),
      ),
    );
  }
  Future<void> _confirmPayment() async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .update({
      'paymentStatus': 'confirmed',
      'rideStarted': true,
      'status': 'in_progress',
      'paymentConfirmedAt': FieldValue.serverTimestamp(),
    });
    _showSuccess("Payment confirmed! Ride started 🎉");
  }

  Widget _buildRiderWaitingOrPinPanel() {
    final status = _rideData['paymentStatus'] as String? ?? 'pending';
    if (status == 'awaiting_confirmation') {
      return _surfaceCard(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.yellowDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.yellow.withOpacity(0.5)),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: T.yellow, size: 28),
          ),
          const SizedBox(height: 16),
          const Text("Payment Sent! 🎉",
              style: TextStyle(color: T.txtDark, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            "Waiting for your driver to confirm payment.\nRide will start automatically once confirmed.",
            textAlign: TextAlign.center,
            style: TextStyle(color: T.txtMed, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          _waitingIndicator("Waiting for driver confirmation..."),
        ]),
      );
    }
    return _buildRiderPinPanel();
  }
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(rideId: widget.rideId)),
    );
  }
  Widget _buildPreRideActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.yellow.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [

          // CHAT
          GestureDetector(
            onTap: _openChat,
            child: Column(
              children: const [
                Icon(Icons.chat_bubble_rounded, color: T.yellow, size: 26),
                SizedBox(height: 6),
                Text(
                  "Chat",
                  style: TextStyle(
                    color: T.txtWhite,
                    fontWeight: FontWeight.w700,
                  ),
                )
              ],
            ),
          ),

          // TRACK
          GestureDetector(
            onTap: _openTracking,
            child: Column(
              children: const [
                Icon(Icons.map_rounded, color: T.yellow, size: 26),
                SizedBox(height: 6),
                Text(
                  "Track",
                  style: TextStyle(
                    color: T.txtWhite,
                    fontWeight: FontWeight.w700,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
                    if (data['paymentStatus'] == 'confirmed' && data['rideStarted'] == true && !_isVerified) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _isVerified = true);
                        _unlockController.forward();
                      });
                    }
                    _rideData = data;
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      children: [
                        _buildRouteCard(),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            if (!_isVerified)
                              widget.isDriver
                                  ? _buildDriverCodePanel()
                                  : _buildRiderWaitingOrPinPanel(),

                            // AFTER
                            if (_rideData['rideCode'] != null && !_isVerified) ...[
                              const SizedBox(height: 16),
                              _buildPreRideActions(),
                            ],

                            if (_isVerified) _buildUnlockedPanel(),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: T.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8)],
              ),
              child: const Icon(Icons.arrow_back, color: T.txtDark, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.directions_car, color: T.yellow, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GharTak',
              style: TextStyle(
                  color: T.txtWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5),
            ),
          ),
          if (_isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: T.yellowDim,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.yellow, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_open_rounded, size: 13, color: T.yellow),
                  SizedBox(width: 5),
                  Text('LIVE',
                      style: TextStyle(
                          color: T.yellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Route Card ─────────────────────────────────────────────────────────────
  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.navyCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _routeRow(
            icon: Icons.trip_origin,
            iconColor: T.yellow,
            label: 'From',
            value: _rideData['from'] ?? '—',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17),
            child: Container(width: 2, height: 20, color: T.yellow.withOpacity(0.3)),
          ),
          _routeRow(
            icon: Icons.location_on,
            iconColor: T.red,
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
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
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
                  style: const TextStyle(
                      color: T.txtLight, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: T.txtWhite, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Driver Code Panel ──────────────────────────────────────────────────────
  Widget _buildDriverCodePanel() {
    return _surfaceCard(
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: T.yellowDim,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: T.yellow.withOpacity(0.4)),
                ),
                child: const Icon(Icons.key_rounded, color: T.yellow, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Your Ride Code',
                    style: TextStyle(
                        color: T.txtDark, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this 4-digit code with your rider to start the ride.',
            style: TextStyle(color: T.txtMed, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Pulsing code
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.yellow, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: T.yellow.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _rideCode ?? '----',
                style: const TextStyle(
                  color: T.yellow,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
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
              _showSuccess('Code copied to clipboard');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: T.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: T.txtMed, size: 16),
                  SizedBox(width: 8),
                  Text('Copy Code',
                      style: TextStyle(
                          color: T.txtDark, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Builder(builder: (_) {
            final status = _rideData['paymentStatus'] as String? ?? 'pending';
            if (status == 'awaiting_confirmation') {
              return Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: T.yellowDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.yellow.withOpacity(0.5)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.currency_rupee, color: T.yellow, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Rider has paid. Check your UPI app then confirm to start the ride.",
                        style: TextStyle(color: T.txtDark, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.green,
                      foregroundColor: T.txtWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_rounded, size: 20, color: T.txtWhite),
                      SizedBox(width: 10),
                      Text("Confirm Payment Received",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.txtWhite)),
                    ]),
                  ),
                ),
              ]);
            }
            return _waitingIndicator("Waiting for rider to enter code & pay...");
          }),
        ],
      ),
    );
  }

  // ── Rider PIN Panel ────────────────────────────────────────────────────────
  Widget _buildRiderPinPanel() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final shakeOffset =
            sin(_shakeAnim.value * pi * 6) * 10 * (1 - _shakeAnim.value);
        return Transform.translate(offset: Offset(shakeOffset, 0), child: child);
      },
      child: _surfaceCard(
        child: Column(
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: T.yellowDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: T.yellow.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: T.yellow, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Enter Ride Code',
                      style: TextStyle(
                          color: T.txtDark, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your driver for the 4-digit code to begin the ride.',
              style: TextStyle(color: T.txtMed, fontSize: 13, height: 1.5),
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
                  const Icon(Icons.error_outline, color: T.red, size: 16),
                  const SizedBox(width: 6),
                  Text(_errorText!,
                      style: const TextStyle(
                          color: T.red, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.yellow,
                  foregroundColor: T.txtDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: T.yellow.withOpacity(0.4),
                ),
                child: _isVerifying
                    ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: T.txtDark))
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, size: 20, color: T.txtDark),
                    SizedBox(width: 10),
                    Text('Verify & Start Ride',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: T.txtDark,
                            letterSpacing: 0.5)),
                  ],
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
    final isFocused = _pinFocusNodes[index].hasFocus;
    final hasTxt = _pinControllers[index].text.isNotEmpty;

    return Container(
      width: boxSize,
      height: boxSize + 8,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: hasTxt ? T.yellowDim : T.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? T.yellow : hasTxt ? T.yellow.withOpacity(0.6) : T.border,
          width: isFocused || hasTxt ? 2 : 1.5,
        ),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _pinFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            color: T.txtDark, fontSize: 26, fontWeight: FontWeight.w900),
        decoration: const InputDecoration(counterText: '', border: InputBorder.none),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.isNotEmpty && index < 3) _pinFocusNodes[index + 1].requestFocus();
          if (val.isEmpty && index > 0) _pinFocusNodes[index - 1].requestFocus();
          if (index == 3 && val.isNotEmpty) {
            final all = _pinControllers.map((c) => c.text).join();
            if (all.length == 4) _verifyCode();
          }
          setState(() {});
        },
      ),
    );
  }

  // ── Unlocked Panel ─────────────────────────────────────────────────────────
  Widget _buildUnlockedPanel() {
    return ScaleTransition(
      scale: _unlockAnim,
      child: Column(
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.navyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.yellow.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: T.yellowDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.yellow, width: 1.5),
                  ),
                  child: const Icon(Icons.lock_open_rounded, color: T.yellow, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ride Started! 🎉',
                          style: TextStyle(
                              color: T.txtWhite, fontSize: 17, fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('All features are now unlocked.',
                          style: TextStyle(color: T.txtLight, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section label
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('RIDE ACTIONS',
                style: TextStyle(
                    color: T.txtMed,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ),
          const SizedBox(height: 10),

          // Action grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: (MediaQuery.of(context).size.width - 52) / 2 / 62,
            children: [
              _buildActionTile(
                icon: Icons.map_rounded,
                label: 'Track Ride',
                isYellow: true,
                onTap: _openTracking,
              ),
              _buildActionTile(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isYellow: false,
                onTap: _openChat,
              ),
              _buildActionTile(
                icon: Icons.check_circle_rounded,
                label: 'Complete',
                isYellow: true,
                onTap: _showDoneDialog,
              ),
              _buildActionTile(
                icon: Icons.cancel_rounded,
                label: 'Cancel',
                isYellow: false,
                isDanger: true,
                onTap: _showCancelDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isYellow = true,
    bool isDanger = false,
  }) {
    final bgColor = isDanger
        ? T.red
        : isYellow
        ? T.yellow
        : T.surface;
    final fgColor = (isYellow && !isDanger) ? T.txtDark : T.txtWhite;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: fgColor, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  Future<void> _showDoneDialog() async {
    final confirmed = await _confirmSheet(
      icon: Icons.check_circle_outline,
      iconColor: T.green,
      title: 'Complete Ride?',
      subtitle: 'Both parties must confirm to fully complete the ride.',
      confirmLabel: 'Yes, Complete',
      confirmColor: T.green,
      confirmTextColor: T.txtWhite,
    );
    if (confirmed != true || !mounted) return;

    final rideRef =
    FirebaseFirestore.instance.collection('rides').doc(widget.rideId);

    await rideRef.update({
      widget.isDriver ? 'posterCompleted' : 'accepterCompleted': true,
    });

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
      _showSuccess(bothDone
          ? '✅ Ride completed!'
          : 'Marked as complete! Waiting for the other party…');
    }
  }

  Future<void> _showCancelDialog() async {
    final confirmed = await _confirmSheet(
      icon: Icons.warning_amber_rounded,
      iconColor: T.red,
      title: 'Cancel Ride?',
      subtitle: 'Both parties must confirm to fully cancel the ride.',
      confirmLabel: 'Yes, Cancel',
      confirmColor: T.red,
      confirmTextColor: T.txtWhite,
    );
    if (confirmed != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .update({
      widget.isDriver ? 'posterCancelled' : 'accepterCancelled': true,
    });
    _showError('Cancellation requested.');
  }

  Future<bool?> _confirmSheet({
    required IconData icon,
    required Color iconColor,
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
          color: T.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: T.border, borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: T.txtDark, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: T.txtMed, fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: T.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back',
                        style: TextStyle(
                            color: T.txtMed, fontWeight: FontWeight.w600)),
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
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable Widgets ───────────────────────────────────────────────────────
  Widget _surfaceCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _waitingIndicator(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: T.txtLight),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: T.txtMed, fontSize: 13)),
      ],
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: T.txtDark, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: T.txtDark, fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: T.yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: T.txtWhite, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: T.txtWhite, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: T.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 3),
    ));
  }
}