import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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

class UpiPaymentPage extends StatefulWidget {
  final String rideId;
  final double amount;
  final String driverUpiId;
  final String driverName;
  final String riderId;

  const UpiPaymentPage({
    required this.rideId,
    required this.amount,
    required this.driverUpiId,
    required this.driverName,
    required this.riderId,
    super.key,
  });

  @override
  State<UpiPaymentPage> createState() => _UpiPaymentPageState();
}

class _UpiPaymentPageState extends State<UpiPaymentPage> {
  bool _isPaying = false;

  Future<void> _payWithApp(String appPackage, String appName) async {
    setState(() => _isPaying = true);

    final upiUrl = Uri.parse(
      'upi://pay?pa=${widget.driverUpiId}'
          '&pn=${Uri.encodeComponent(widget.driverName)}'
          '&am=${widget.amount.toStringAsFixed(2)}'
          '&cu=INR'
          '&tn=${Uri.encodeComponent("GharTak Ride Payment")}',
    );

    try {
      final launched = await launchUrl(upiUrl, mode: LaunchMode.externalApplication);

      if (launched) {
        await FirebaseFirestore.instance.collection('payments').add({
          'rideId': widget.rideId,
          'riderId': widget.riderId,
          'driverUPI': widget.driverUpiId,
          'amount': widget.amount,
          'app': appName,
          'status': 'initiated',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({'paymentStatus': 'initiated'});

        if (mounted) _showSuccessSheet();
      } else {
        _showError('$appName not installed');
      }
    } catch (e) {
      _showError('Could not open $appName');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }



  void _showSuccessSheet() {
    final bottom = MediaQuery.of(context).padding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottom),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 24)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Success icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: T.green.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: T.green.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: T.green, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Payment Opened! 🎉',
              style: TextStyle(
                  color: T.txtDark, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Complete the payment in your UPI app.\n₹${widget.amount.toStringAsFixed(0)} → ${widget.driverName}',
            style: const TextStyle(color: T.txtMed, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: T.yellow,
                foregroundColor: T.txtDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20, color: T.txtDark),
                  SizedBox(width: 10),
                  Text('Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.txtDark)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final apps = [
      {
        'name': 'PhonePe',
        'package': 'com.phonepe.app',
        'color': const Color(0xFF5F259F),
        'icon': Icons.phone_android,
      },
      {
        'name': 'Google Pay',
        'package': 'com.google.android.apps.nbu.paisa.user',
        'color': const Color(0xFF1A73E8),
        'icon': Icons.g_mobiledata,
      },
      {
        'name': 'Paytm',
        'package': 'net.one97.paytm',
        'color': const Color(0xFF00BAF2),
        'icon': Icons.account_balance_wallet,
      },
      {
        'name': 'BHIM',
        'package': 'in.org.npci.upiapp',
        'color': const Color(0xFF004C8F),
        'icon': Icons.currency_rupee,
      },
    ];

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              color: T.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(Icons.currency_rupee, color: T.yellow, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('GharTak',
                      style: TextStyle(
                          color: T.txtWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: T.yellowDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: T.yellow, width: 1.5),
                  ),
                  child: const Text('PAYMENT',
                      style: TextStyle(
                          color: T.yellow,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page title
                    const Text('Pay for Ride',
                        style: TextStyle(
                            color: T.txtDark,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Choose a UPI app to complete your payment',
                        style: TextStyle(color: T.txtMed, fontSize: 13)),

                    const SizedBox(height: 20),

                    // ── Amount card ──────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: T.navyCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: T.yellow.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: T.shadow, blurRadius: 12, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(children: [
                        const Text('TOTAL FARE',
                            style: TextStyle(
                                color: T.txtLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Text('₹${widget.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: T.yellow,
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: T.yellowDim,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: T.yellow.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.person, color: T.yellow, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.driverName}  •  ${widget.driverUpiId}',
                              style: const TextStyle(
                                  color: T.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // ── Section label ────────────────────────────────────────
                    const Text('PAY WITH',
                        style: TextStyle(
                            color: T.txtMed,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 12),

                    // ── App list card ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: T.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: T.border),
                        boxShadow: [BoxShadow(
                            color: T.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: apps.asMap().entries.map((entry) {
                          final i = entry.key;
                          final app = entry.value;
                          final appColor = app['color'] as Color;

                          return Column(children: [
                            if (i > 0)
                              const Divider(height: 1, thickness: 1, color: T.border),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: GestureDetector(
                                onTap: _isPaying
                                    ? null
                                    : () => _payWithApp(
                                    app['package'] as String,
                                    app['name'] as String),
                                child: Row(children: [
                                  // App icon
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: appColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: appColor.withOpacity(0.25)),
                                    ),
                                    child: Icon(app['icon'] as IconData,
                                        color: appColor, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(app['name'] as String,
                                        style: const TextStyle(
                                            color: T.txtDark,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  // Pay button
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: T.yellow,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: _isPaying
                                        ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: T.txtDark))
                                        : const Text('Pay',
                                        style: TextStyle(
                                            color: T.txtDark,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                  ),
                                ]),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                 ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}