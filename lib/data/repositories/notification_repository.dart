import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../../notification_api.dart';

/// Repository for creating, delivering, and reading notifications.
class NotificationRepository {
  final FirebaseFirestore? _customFirestore;

  NotificationRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference _userNotifsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// Delivers an in-app notification and dispatches background FCM push.
  Future<void> send({
    required String recipientId,
    required String title,
    required String body,
    required AppNotificationType type,
    String? relatedId,
  }) async {
    try {
      // 1. Write to in-app notifications subcollection
      await _userNotifsRef(recipientId).add({
        'title': title,
        'body': body,
        'type': type.toDbString(),
        if (relatedId != null) 'relatedId': relatedId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Best-effort push notification
      sendNotification(
        userId: recipientId,
        title: title,
        body: body,
        data: {
          'type': type.toDbString(),
          if (relatedId != null) 'relatedId': relatedId,
        },
      ).catchError((_) {});
    } catch (e) {
      // Notification errors should never break main business operations
    }
  }

  /// Streams notifications for a given user ordered by time descending.
  Stream<List<AppNotificationModel>> streamNotifications(String userId) {
    return _userNotifsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotificationModel.fromFirestore(d))
              .toList(),
        );
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String userId, String notifId) async {
    try {
      await _userNotifsRef(userId).doc(notifId).update({'isRead': true});
    } catch (_) {}
  }

  /// Marks all notifications for a user as read.
  Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _userNotifsRef(
        userId,
      ).where('isRead', isEqualTo: false).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Deletes a notification.
  Future<void> deleteNotification(String userId, String notifId) async {
    try {
      await _userNotifsRef(userId).doc(notifId).delete();
    } catch (_) {}
  }
}
