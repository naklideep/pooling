import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of notifications in RideBuddyy.
enum AppNotificationType {
  invitationReceived,
  invitationAccepted,
  invitationDeclined,
  bookingRequest,
  bookingApproved,
  bookingRejected,
  bookingCancelled,
  rideReminder,
  scheduleUpdated,
  general;

  static AppNotificationType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'invitation_received':
      case 'invitationreceived':
        return AppNotificationType.invitationReceived;
      case 'invitation_accepted':
      case 'invitationaccepted':
        return AppNotificationType.invitationAccepted;
      case 'invitation_declined':
      case 'invitationdeclined':
        return AppNotificationType.invitationDeclined;
      case 'booking_request':
      case 'bookingrequest':
        return AppNotificationType.bookingRequest;
      case 'booking_approved':
      case 'bookingapproved':
        return AppNotificationType.bookingApproved;
      case 'booking_rejected':
      case 'bookingrejected':
        return AppNotificationType.bookingRejected;
      case 'booking_cancelled':
      case 'bookingcancelled':
        return AppNotificationType.bookingCancelled;
      case 'ride_reminder':
      case 'ridereminder':
        return AppNotificationType.rideReminder;
      case 'schedule_updated':
      case 'scheduleupdated':
        return AppNotificationType.scheduleUpdated;
      case 'general':
      default:
        return AppNotificationType.general;
    }
  }

  String toDbString() {
    switch (this) {
      case AppNotificationType.invitationReceived:
        return 'invitation_received';
      case AppNotificationType.invitationAccepted:
        return 'invitation_accepted';
      case AppNotificationType.invitationDeclined:
        return 'invitation_declined';
      case AppNotificationType.bookingRequest:
        return 'booking_request';
      case AppNotificationType.bookingApproved:
        return 'booking_approved';
      case AppNotificationType.bookingRejected:
        return 'booking_rejected';
      case AppNotificationType.bookingCancelled:
        return 'booking_cancelled';
      case AppNotificationType.rideReminder:
        return 'ride_reminder';
      case AppNotificationType.scheduleUpdated:
        return 'schedule_updated';
      case AppNotificationType.general:
        return 'general';
    }
  }
}

/// Model representing an in-app notification in `users/{userId}/notifications/{notifId}`.
class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final String? relatedId; // rideId, invitationId, scheduleId, etc.
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return AppNotificationModel(
      id: doc.id,
      title: d['title'] ?? 'Notification',
      body: d['body'] ?? '',
      type: AppNotificationType.fromString(d['type']),
      relatedId: d['relatedId'],
      isRead: d['isRead'] ?? false,
      createdAt: parseDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type.toDbString(),
      if (relatedId != null) 'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
