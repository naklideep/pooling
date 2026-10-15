import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

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
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Booking flow handled in Phase 3
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Booking flow coming in Phase 3 — stay tuned!',
                            ),
                          ),
                        );
                      },
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
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'This is your own ride',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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
