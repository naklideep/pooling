import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../pages/post_ride.dart';

/// Offer Ride tab — wraps the existing PostRidePage inside the
/// new bottom-navigation shell so it gets the correct header
/// and background.
class OfferRideTab extends StatelessWidget {
  final String userId;
  const OfferRideTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Share your journey'),
          const Expanded(
            // PostRidePage already scrolls internally via ListView.
            child: PostRidePage(),
          ),
        ],
      ),
    );
  }
}
