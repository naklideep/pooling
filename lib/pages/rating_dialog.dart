import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this after ride completes to show a rating bottom sheet.
/// [ratedUserId]   — the person being rated
/// [ratedUserName] — their display name
/// [rideId]        — used to prevent duplicate ratings
Future<void> showRatingDialog({
  required BuildContext context,
  required String ratedUserId,
  required String ratedUserName,
  required String rideId,
  required String currentUserId,
}) async {
  // Don't show if already rated
  final existing = await FirebaseFirestore.instance
      .collection('users')
      .doc(ratedUserId)
      .collection('ratings')
      .doc('${rideId}_$currentUserId')
      .get();
  if (existing.exists) return;

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RatingSheet(
      ratedUserId: ratedUserId,
      ratedUserName: ratedUserName,
      rideId: rideId,
      currentUserId: currentUserId,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  final String ratedUserId;
  final String ratedUserName;
  final String rideId;
  final String currentUserId;

  const _RatingSheet({
    required this.ratedUserId,
    required this.ratedUserName,
    required this.rideId,
    required this.currentUserId,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with SingleTickerProviderStateMixin {
  int _selected = 0;
  int _hovered = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  late AnimationController _successController;
  late Animation<double> _successAnim;

  // Star labels
  static const _labels = ['', 'Terrible', 'Bad', 'Okay', 'Good', 'Amazing!'];
  static const _emojis = ['', '😤', '😕', '😐', '😊', '🤩'];

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successAnim = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == 0) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final ratingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ratedUserId)
          .collection('ratings')
          .doc('${widget.rideId}_${widget.currentUserId}');

      // Save rating
      await ratingRef.set({
        'rating': _selected,
        'comment': _commentController.text.trim(),
        'rideId': widget.rideId,
        'fromUserId': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Recalculate average on user doc
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ratedUserId)
          .collection('ratings')
          .get();

      final total = ratingsSnap.docs.length;
      final sum = ratingsSnap.docs
          .map((d) => (d.data()['rating'] as num).toInt())
          .reduce((a, b) => a + b);
      final avg = sum / total;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.ratedUserId)
          .update({
        'averageRating': double.parse(avg.toStringAsFixed(1)),
        'totalRatings': total,
      });

      setState(() {
        _submitting = false;
        _submitted = true;
      });
      _successController.forward();
      HapticFeedback.heavyImpact();

      // Auto close after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit rating: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B5E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: _submitted ? _buildSuccess() : _buildForm(screenWidth),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return ScaleTransition(
      scale: _successAnim,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.greenAccent, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Rating Submitted!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thanks for your feedback 🙌',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Rating form ────────────────────────────────────────────────────────────
  Widget _buildForm(double screenWidth) {
    final activeLabel = _hovered > 0
        ? _labels[_hovered]
        : _selected > 0
        ? _labels[_selected]
        : 'Tap to rate';
    final activeEmoji = _hovered > 0
        ? _emojis[_hovered]
        : _selected > 0
        ? _emojis[_selected]
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Avatar + name
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 2),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF6366F1),
                child: Text(
                  _getInitials(widget.ratedUserName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate your ride with',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    widget.ratedUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Emoji + label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            activeEmoji.isNotEmpty ? '$activeEmoji  $activeLabel' : activeLabel,
            key: ValueKey(activeLabel),
            style: TextStyle(
              color: _selected > 0 || _hovered > 0
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final isActive =
                starIndex <= (_hovered > 0 ? _hovered : _selected);
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selected = starIndex);
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = starIndex),
                onExit: (_) => setState(() => _hovered = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isActive ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: screenWidth < 360 ? 36 : 44,
                      color: isActive
                          ? const Color(0xFFFBBF24)
                          : Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 28),

        // Comment box
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border:
            Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)...',
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle:
              TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_selected == 0 || _submitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected > 0
                  ? const Color(0xFF6366F1)
                  : Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.white.withOpacity(0.08),
            ),
            child: _submitting
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
                : Text(
              _selected == 0 ? 'Select a rating first' : 'Submit Rating',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Skip
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Skip for now',
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }
}