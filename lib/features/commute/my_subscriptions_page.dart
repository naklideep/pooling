import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';

/// Screen displaying all active and paused subscriptions for a commuter.
class MySubscriptionsPage extends StatefulWidget {
  final String userId;

  const MySubscriptionsPage({super.key, required this.userId});

  @override
  State<MySubscriptionsPage> createState() => _MySubscriptionsPageState();
}

class _MySubscriptionsPageState extends State<MySubscriptionsPage> {
  final _subRepo = SubscriptionRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'My Commute Subscriptions'),
          Expanded(
            child: StreamBuilder<List<SubscriptionModel>>(
              stream: _subRepo.streamSubscriberSubscriptions(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final subs = snapshot.data ?? [];
                if (subs.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.subscriptions_outlined,
                    title: 'No active subscriptions',
                    subtitle:
                        'Subscribe to a publisher\'s daily route from "Discover Publishers" to get quick access to recurring seats.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: subs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = subs[i];
                    final isPaused = item.status == SubscriptionStatus.paused;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isPaused ? AppColors.border : AppColors.yellow,
                          width: isPaused ? 0.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x06000000),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.yellow.withValues(alpha: 0.2),
                                    backgroundImage: item.subscriberPhoto != null
                                        ? NetworkImage(item.subscriberPhoto!)
                                        : null,
                                    child: item.subscriberPhoto == null
                                        ? const Icon(Icons.person, size: 16, color: AppColors.navy)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.publisherName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaused
                                      ? Colors.grey.shade200
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.status.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isPaused
                                        ? Colors.grey.shade700
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${item.from} → ${item.to}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.pickupName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Pickup Point: ${item.pickupName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Departure: ${item.departureTime}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 0),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  isPaused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                                label: Text(
                                  isPaused ? 'Resume' : 'Pause',
                                  style: const TextStyle(color: AppColors.navy),
                                ),
                                onPressed: () async {
                                  if (isPaused) {
                                    await _subRepo.resumeSubscription(item.id);
                                  } else {
                                    await _subRepo.pauseSubscription(item.id);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel Subscription?'),
                                      content: const Text(
                                        'You will stop receiving updates and priority access for this publisher\'s commute.',
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
                                          child: const Text('Cancel Subscription'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await _subRepo.cancelSubscription(
                                      subscriptionId: item.id,
                                      scheduleId: item.scheduleId,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
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
    );
  }
}
