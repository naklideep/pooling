import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class SubscriptionResult {
  final bool success;
  final String? message;
  final String? subscriptionId;

  const SubscriptionResult._({
    required this.success,
    this.message,
    this.subscriptionId,
  });

  factory SubscriptionResult.ok({String? message, String? subscriptionId}) =>
      SubscriptionResult._(
        success: true,
        message: message,
        subscriptionId: subscriptionId,
      );

  factory SubscriptionResult.fail(String error) =>
      SubscriptionResult._(success: false, message: error);
}

/// Repository managing publisher–subscriber relationships for recurring routes.
class SubscriptionRepository {
  final FirebaseFirestore? _customFirestore;
  final NotificationRepository _notifRepo;

  SubscriptionRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notifRepo,
  }) : _customFirestore = firestore,
       _notifRepo = notifRepo ?? NotificationRepository(firestore: firestore);

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference get _subsRef => _firestore.collection('subscriptions');
  CollectionReference get _schedulesRef =>
      _firestore.collection('commuteSchedules');

  /// Subscribes a user to a recurring commute schedule.
  Future<SubscriptionResult> subscribe(SubscriptionModel subscription) async {
    try {
      // Prevent subscribing to own commute
      if (subscription.subscriberId == subscription.publisherId) {
        return SubscriptionResult.fail('You cannot subscribe to your own commute.');
      }

      // Check duplicate active subscription
      final dup = await _subsRef
          .where('subscriberId', isEqualTo: subscription.subscriberId)
          .where('scheduleId', isEqualTo: subscription.scheduleId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        return SubscriptionResult.fail(
          'You are already subscribed to this commute.',
        );
      }

      final docRef = _subsRef.doc();
      final subId = docRef.id;

      final batch = _firestore.batch();
      batch.set(docRef, subscription.toMap());
      batch.update(_schedulesRef.doc(subscription.scheduleId), {
        'subscriberCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Notify the publisher
      _notifRepo.send(
        recipientId: subscription.publisherId,
        title: 'New Commute Subscriber! 🎉',
        body:
            '${subscription.subscriberName} subscribed to your commute (${subscription.from} → ${subscription.to}).',
        type: AppNotificationType.general,
        relatedId: subId,
      );

      return SubscriptionResult.ok(
        subscriptionId: subId,
        message: 'Subscribed to commute successfully!',
      );
    } catch (e) {
      return SubscriptionResult.fail('Failed to subscribe: $e');
    }
  }

  /// Pauses an active subscription.
  Future<SubscriptionResult> pauseSubscription(String subscriptionId) async {
    try {
      await _subsRef.doc(subscriptionId).update({
        'status': SubscriptionStatus.paused.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return SubscriptionResult.ok(message: 'Subscription paused.');
    } catch (e) {
      return SubscriptionResult.fail('Failed to pause: $e');
    }
  }

  /// Resumes a paused subscription.
  Future<SubscriptionResult> resumeSubscription(String subscriptionId) async {
    try {
      await _subsRef.doc(subscriptionId).update({
        'status': SubscriptionStatus.active.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return SubscriptionResult.ok(message: 'Subscription resumed.');
    } catch (e) {
      return SubscriptionResult.fail('Failed to resume: $e');
    }
  }

  /// Cancels an active or paused subscription.
  Future<SubscriptionResult> cancelSubscription({
    required String subscriptionId,
    required String scheduleId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_subsRef.doc(subscriptionId), {
        'status': SubscriptionStatus.cancelled.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_schedulesRef.doc(scheduleId), {
        'subscriberCount': FieldValue.increment(-1),
      });
      await batch.commit();

      return SubscriptionResult.ok(message: 'Subscription cancelled.');
    } catch (e) {
      return SubscriptionResult.fail('Failed to cancel: $e');
    }
  }

  /// Streams active subscriptions for a given subscriber.
  Stream<List<SubscriptionModel>> streamSubscriberSubscriptions(
    String subscriberId,
  ) {
    return _subsRef
        .where('subscriberId', isEqualTo: subscriberId)
        .where('status', whereIn: ['active', 'paused'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubscriptionModel.fromFirestore(d))
              .toList(),
        );
  }

  /// Streams subscribers for a publisher's schedule.
  Stream<List<SubscriptionModel>> streamScheduleSubscribers(String scheduleId) {
    return _subsRef
        .where('scheduleId', isEqualTo: scheduleId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubscriptionModel.fromFirestore(d))
              .toList(),
        );
  }
}
