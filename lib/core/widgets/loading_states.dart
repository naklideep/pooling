import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Skeleton loading state for a ride card.
class RideCardSkeleton extends StatefulWidget {
  const RideCardSkeleton({super.key});

  @override
  State<RideCardSkeleton> createState() => _RideCardSkeletonState();
}

class _RideCardSkeletonState extends State<RideCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        return Column(
          children: List.generate(
            3,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(0.7),
                  const SizedBox(height: 10),
                  _line(0.5),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _box(60, 22),
                      const SizedBox(width: 8),
                      _box(50, 22),
                      const SizedBox(width: 8),
                      _box(80, 22),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _line(double widthFraction) {
    return Container(
      height: 14,
      width: MediaQuery.of(context).size.width * widthFraction,
      decoration: BoxDecoration(
        color: Color.fromRGBO(
          26,
          35,
          64,
          _shimmer.value,
        ), // navy with shimmer opacity
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }

  Widget _box(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Color.fromRGBO(26, 35, 64, _shimmer.value * 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

/// Full-page loading overlay.
class PoolingLoadingOverlay extends StatelessWidget {
  final String? message;
  const PoolingLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.navy,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(
                color: AppColors.yellow,
                strokeWidth: 2.5,
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for use in lists.
class PoolingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const PoolingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0x08000000), blurRadius: 16),
                ],
              ),
              child: Icon(icon, size: 44, color: AppColors.navy),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Convenience alias for PoolingEmptyState.
typedef EmptyStateView = PoolingEmptyState;
