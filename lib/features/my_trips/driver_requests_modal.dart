import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ride_request_model.dart';
import '../../data/repositories/booking_repository.dart';

/// Modal bottom sheet allowing a driver to view and manage (approve/reject)
/// pending passenger booking requests for a specific ride.
class DriverRequestsModal extends StatefulWidget {
  final String rideId;
  final String driverId;

  const DriverRequestsModal({
    super.key,
    required this.rideId,
    required this.driverId,
  });

  static Future<void> show(
    BuildContext context, {
    required String rideId,
    required String driverId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverRequestsModal(rideId: rideId, driverId: driverId),
    );
  }

  @override
  State<DriverRequestsModal> createState() => _DriverRequestsModalState();
}

class _DriverRequestsModalState extends State<DriverRequestsModal> {
  final _bookingRepo = BookingRepository();
  final Set<String> _processingIds = {};

  Future<void> _approve(RideRequestModel req) async {
    setState(() => _processingIds.add(req.id));
    final res = await _bookingRepo.approveRequest(
      requestId: req.id,
      driverId: widget.driverId,
    );
    if (mounted) {
      setState(() => _processingIds.remove(req.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? (res.success ? 'Approved!' : 'Failed')),
          backgroundColor: res.success ? AppColors.navy : AppColors.error,
        ),
      );
    }
  }

  Future<void> _reject(RideRequestModel req) async {
    setState(() => _processingIds.add(req.id));
    final res = await _bookingRepo.rejectRequest(
      requestId: req.id,
      driverId: widget.driverId,
    );
    if (mounted) {
      setState(() => _processingIds.remove(req.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Rejected.'),
          backgroundColor: AppColors.navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.35,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_outline_rounded,
                      color: AppColors.navy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Booking Requests',
                      style: TextStyle(
                        fontSize: 18,
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
            Expanded(
              child: StreamBuilder<List<RideRequestModel>>(
                stream: _bookingRepo.streamPendingRequestsForRide(
                  widget.rideId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.yellow),
                    );
                  }

                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: AppColors.success,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'All caught up!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No pending booking requests for this ride.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final isBusy = _processingIds.contains(req.id);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.yellow,
                              backgroundImage: req.passengerPhoto != null
                                  ? NetworkImage(req.passengerPhoto!)
                                  : null,
                              child: req.passengerPhoto == null
                                  ? Text(
                                      req.passengerName.isNotEmpty
                                          ? req.passengerName[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req.passengerName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Requested ${req.requestedSeats} seat${req.requestedSeats == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isBusy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.navy,
                                  ),
                                ),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.error,
                                ),
                                tooltip: 'Reject',
                                onPressed: () => _reject(req),
                              ),
                              const SizedBox(width: 4),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.yellow,
                                  foregroundColor: AppColors.navy,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () => _approve(req),
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
