import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/booking_repository.dart';

/// Sheet displaying confirmed passengers on a ride occurrence with boarding PIN and management actions.
class PassengerListSheet extends StatelessWidget {
  final String rideId;
  final String driverId;
  final String rideCode;

  const PassengerListSheet({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.rideCode,
  });

  @override
  Widget build(BuildContext context) {
    final bookingRepo = BookingRepository();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Confirmed Passengers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.yellow),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_rounded, size: 14, color: AppColors.navy),
                    const SizedBox(width: 4),
                    Text(
                      'PIN: $rideCode',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<BookingModel>>(
            stream: bookingRepo.streamRideBookings(rideId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final bookings = snapshot.data ?? [];
              if (bookings.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No confirmed passengers on this ride yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final b = bookings[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.yellow.withValues(alpha: 0.2),
                          backgroundImage: b.passengerPhoto != null
                              ? NetworkImage(b.passengerPhoto!)
                              : null,
                          child: b.passengerPhoto == null
                              ? const Icon(Icons.person, size: 18, color: AppColors.navy)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.passengerName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                '${b.seatsBooked} seat(s) • ₹${b.cost}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                          tooltip: 'Remove Passenger',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancel Passenger Booking?'),
                                content: Text(
                                  'Remove ${b.passengerName} from this ride? The seat will be restored.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Keep'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove Passenger'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await bookingRepo.cancelBooking(
                                bookingId: b.id,
                                userId: driverId,
                                reason: 'Cancelled by driver.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
