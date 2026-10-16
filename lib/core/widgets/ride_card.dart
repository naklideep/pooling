import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/booking_repository.dart';
import '../../features/bookings/passenger_list_sheet.dart';
import '../../features/invitations/send_invitation_sheet.dart';

/// Compact/full ride list card used in Home and Find Ride tabs.
///
/// Shows pickup → destination, departure time, driver name,
/// remaining seats, and cost. Tapping opens the ride detail sheet.
class RideCard extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;
  final String currentUserId;

  /// When [compact] is true, some secondary details are hidden.
  final bool compact;

  const RideCard({
    super.key,
    required this.rideId,
    required this.rideData,
    required this.currentUserId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = rideData['from'] as String? ?? 'Unknown';
    final to = rideData['to'] as String? ?? 'Unknown';
    final remaining =
        ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num).toInt();
    final cost = rideData['estimatedCost'];
    final ts = rideData['dateTime'] as dynamic;
    final DateTime? dateTime = ts != null
        ? (ts.runtimeType.toString().contains('Timestamp')
              ? (ts as dynamic).toDate() as DateTime
              : null)
        : null;
    final driver = rideData['postedByName'] as String? ?? 'Unknown';
    final rideType = rideData['rideType'] as String? ?? 'Car';
    final isOwn = rideData['riderId'] == currentUserId;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Yellow accent top bar
            Container(
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  _buildRoute(from, to),
                  const SizedBox(height: 12),
                  const Divider(height: 0),
                  const SizedBox(height: 10),
                  // Chips row
                  _buildChipRow(remaining, cost, dateTime, rideType),
                  if (!compact) ...[
                    const SizedBox(height: 10),
                    _buildDriverRow(driver, isOwn),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoute(String from, String to) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              ),
            ),
            Container(width: 2, height: 20, color: AppColors.border),
            const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                to,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipRow(
    int remaining,
    dynamic cost,
    DateTime? dateTime,
    String rideType,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          icon: Icons.event_seat_outlined,
          label: '$remaining seat${remaining == 1 ? '' : 's'}',
          color: AppColors.navy,
        ),
        if (cost != null)
          _Chip(
            icon: Icons.currency_rupee,
            label: '₹$cost',
            color: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFE8F5E9),
          ),
        if (dateTime != null)
          _Chip(
            icon: Icons.schedule_outlined,
            label: DateFormat('MMM d, h:mm a').format(dateTime),
            color: AppColors.textSecondary,
            bgColor: AppColors.surfaceDim,
          ),
        _Chip(
          icon: rideType == 'Bike'
              ? Icons.two_wheeler
              : Icons.directions_car_outlined,
          label: rideType,
          color: AppColors.textSecondary,
          bgColor: AppColors.surfaceDim,
        ),
      ],
    );
  }

  Widget _buildDriverRow(String driver, bool isOwn) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, size: 14, color: AppColors.navy),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isOwn ? 'Your ride' : driver,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isOwn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Your ride',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    // Full ride detail bottom sheet — will be expanded in Phase 2.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideDetailSheet(
        rideId: rideId,
        rideData: rideData,
        currentUserId: currentUserId,
      ),
    );
  }
}

/// Simple info chip.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.navy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ride Detail Bottom Sheet ─────────────────────────────────────────────────

class _RideDetailSheet extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;
  final String currentUserId;

  const _RideDetailSheet({
    required this.rideId,
    required this.rideData,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final from = rideData['from'] as String? ?? 'Unknown';
    final to = rideData['to'] as String? ?? 'Unknown';
    final remaining =
        ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num).toInt();
    final cost = rideData['estimatedCost'];
    final ts = rideData['dateTime'] as dynamic;
    final DateTime? dateTime = ts != null
        ? (ts.runtimeType.toString().contains('Timestamp')
              ? (ts as dynamic).toDate() as DateTime
              : null)
        : null;
    final driver = rideData['postedByName'] as String? ?? 'Unknown';
    final distKm = (rideData['distance_km'] as num?)?.toStringAsFixed(1);
    final durMin = (rideData['duration_min'] as num?)?.toStringAsFixed(0);
    final rideType = rideData['rideType'] as String? ?? 'Car';
    final isOwn = rideData['riderId'] == currentUserId;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.navy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ride Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Route card
                  _DetailCard(
                    child: Column(
                      children: [
                        _routeRow(Icons.circle, const Color(0xFF4CAF50), from),
                        Container(
                          margin: const EdgeInsets.only(left: 9),
                          width: 2,
                          height: 20,
                          color: AppColors.border,
                        ),
                        _routeRow(Icons.location_on, Colors.redAccent, to),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (dateTime != null)
                    _DetailCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat(
                              'EEE, MMM dd · hh:mm a',
                            ).format(dateTime),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: [
                      _MiniTile(
                        'Seats',
                        '$remaining available',
                        Icons.event_seat_outlined,
                      ),
                      _MiniTile(
                        'Ride type',
                        rideType,
                        Icons.directions_car_outlined,
                      ),
                      if (distKm != null)
                        _MiniTile(
                          'Distance',
                          '$distKm km',
                          Icons.straighten_rounded,
                        ),
                      if (durMin != null)
                        _MiniTile(
                          'Duration',
                          '$durMin min',
                          Icons.timer_outlined,
                        ),
                      if (cost != null)
                        _MiniTile(
                          'Est. cost',
                          '₹$cost',
                          Icons.currency_rupee_rounded,
                        ),
                      _MiniTile('Driver', driver, Icons.person_outline),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Book button
                  if (!isOwn && remaining > 0)
                    FilledButton.icon(
                      onPressed: () => _openBookingRequestDialog(
                        context,
                        ctx,
                        remaining,
                        cost,
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Request this Ride'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    )
                  else if (isOwn)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.people_alt_outlined, size: 18),
                            label: const Text(
                              'Passengers & PIN',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => PassengerListSheet(
                                  rideId: rideId,
                                  driverId: currentUserId,
                                  rideCode: (rideData['rideCode'] ?? '----').toString(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              side: const BorderSide(color: AppColors.navy),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: const Text(
                              'Invite Riders',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => SendInvitationSheet(
                                  publisherId: currentUserId,
                                  initialRideId: rideId,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Ride is full',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBookingRequestDialog(
    BuildContext rootContext,
    BuildContext sheetContext,
    int remaining,
    dynamic cost,
  ) {
    int selectedSeats = 1;
    final num perSeat = cost is num ? cost : 0;

    showDialog<void>(
      context: rootContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalCost = selectedSeats * perSeat;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.event_seat_rounded, color: AppColors.navy),
                SizedBox(width: 10),
                Text(
                  'Select Seats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How many seats would you like to request for this trip?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: selectedSeats > 1
                          ? () => setDialogState(() => selectedSeats--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '$selectedSeats',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: selectedSeats < remaining
                          ? () => setDialogState(() => selectedSeats++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Max $remaining seat${remaining == 1 ? '' : 's'} available',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (perSeat > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated Contribution',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₹$totalCost',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(sheetContext);

                  final user = FirebaseAuth.instance.currentUser;
                  final repo = BookingRepository();
                  final res = await repo.requestSeat(
                    rideId: rideId,
                    passengerId: currentUserId,
                    passengerName:
                        user?.displayName ??
                        user?.email?.split('@').first ??
                        'Passenger',
                    passengerPhoto: user?.photoURL,
                    requestedSeats: selectedSeats,
                  );

                  if (rootContext.mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          res.message ??
                              (res.success
                                  ? 'Request sent!'
                                  : 'Request failed'),
                        ),
                        backgroundColor: res.success
                            ? AppColors.navy
                            : AppColors.error,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Send Request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _routeRow(IconData icon, Color iconColor, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared detail widgets ────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.yellow),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
