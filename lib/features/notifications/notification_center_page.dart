import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

/// In-app Notification Center displaying ride updates, invitations, and alerts.
class NotificationCenterPage extends StatefulWidget {
  final String userId;

  const NotificationCenterPage({super.key, required this.userId});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final _repo = NotificationRepository();

  IconData _getIconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.invitationReceived:
      case AppNotificationType.invitationAccepted:
      case AppNotificationType.invitationDeclined:
        return Icons.mail_outline_rounded;
      case AppNotificationType.bookingRequest:
      case AppNotificationType.bookingApproved:
      case AppNotificationType.bookingCancelled:
        return Icons.event_seat_outlined;
      case AppNotificationType.rideReminder:
        return Icons.alarm_rounded;
      case AppNotificationType.scheduleUpdated:
        return Icons.update_rounded;
      case AppNotificationType.general:
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getColorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.invitationReceived:
      case AppNotificationType.bookingApproved:
        return const Color(0xFF2E7D32); // Green
      case AppNotificationType.invitationDeclined:
      case AppNotificationType.bookingCancelled:
      case AppNotificationType.bookingRejected:
        return const Color(0xFFD32F2F); // Red
      case AppNotificationType.bookingRequest:
      case AppNotificationType.rideReminder:
        return AppColors.navy;
      case AppNotificationType.scheduleUpdated:
      case AppNotificationType.general:
      default:
        return AppColors.yellowDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(
            subtitle: 'Notifications & Alerts',
            trailing: IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              tooltip: 'Mark all as read',
              onPressed: () async {
                await _repo.markAllAsRead(widget.userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppNotificationModel>>(
              stream: _repo.streamNotifications(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifs = snapshot.data ?? [];
                if (notifs.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    subtitle:
                        'Updates about invitations, bookings, and commutes will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = notifs[i];
                    final color = _getColorForType(item.type);
                    final icon = _getIconForType(item.type);

                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        _repo.deleteNotification(widget.userId, item.id);
                      },
                      child: GestureDetector(
                        onTap: () {
                          if (!item.isRead) {
                            _repo.markAsRead(widget.userId, item.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? AppColors.surface
                                : AppColors.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead
                                  ? AppColors.border
                                  : AppColors.yellow,
                              width: item.isRead ? 0.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x06000000),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: item.isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, h:mm a')
                                              .format(item.createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.body,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!item.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.yellow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
