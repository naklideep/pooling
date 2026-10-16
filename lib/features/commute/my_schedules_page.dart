import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';
import '../../data/models/commute_schedule_model.dart';
import '../../data/repositories/commute_repository.dart';
import 'create_commute_page.dart';

/// Screen allowing publishers to view and manage their recurring commute schedules.
class MySchedulesPage extends StatefulWidget {
  final String userId;

  const MySchedulesPage({super.key, required this.userId});

  @override
  State<MySchedulesPage> createState() => _MySchedulesPageState();
}

class _MySchedulesPageState extends State<MySchedulesPage> {
  final _commuteRepo = CommuteRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Commute'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCommutePage()),
          );
        },
      ),
      body: Column(
        children: [
          PoolingHeader(subtitle: 'My Recurring Commutes'),
          Expanded(
            child: StreamBuilder<List<CommuteScheduleModel>>(
              stream: _commuteRepo.streamPublisherSchedules(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final schedules = snapshot.data ?? [];
                if (schedules.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.repeat_rounded,
                    title: 'No recurring commutes published',
                    subtitle:
                        'Create a reusable commute schedule to automatically publish daily rides for your work or college travel.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = schedules[i];
                    final isPaused = item.status == CommuteStatus.paused;
                    final isEnded = item.status == CommuteStatus.ended;

                    Color statusColor = const Color(0xFF2E7D32);
                    if (isPaused) statusColor = Colors.orange;
                    if (isEnded) statusColor = Colors.grey;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isPaused ? Colors.orange : AppColors.border,
                          width: isPaused ? 1.0 : 0.5,
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
                              Text(
                                item.daysSummary,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.status.toDbString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Departs ${item.departureTime}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.event_seat_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${item.seats} seats',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${item.subscriberCount} subscriber(s)',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 0),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isEnded) ...[
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
                                      await _commuteRepo.resumeSchedule(item.id);
                                    } else {
                                      await _commuteRepo.pauseSchedule(item.id);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.red),
                                  label: const Text('End', style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('End Commute Schedule?'),
                                        content: const Text(
                                          'Future unconfirmed occurrences will stop generating. Confirmed bookings will remain preserved.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('End Schedule'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await _commuteRepo.endSchedule(item.id);
                                    }
                                  },
                                ),
                              ],
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
