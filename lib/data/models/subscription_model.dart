import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription lifecycle status.
enum SubscriptionStatus {
  active,
  paused,
  cancelled;

  static SubscriptionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'paused':
        return SubscriptionStatus.paused;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }

  String toDbString() => name;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.paused:
        return 'Paused';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Model for a subscriber's subscription to a publisher's recurring commute.
class SubscriptionModel {
  final String id;
  final String subscriberId;
  final String subscriberName;
  final String? subscriberPhoto;
  final String publisherId;
  final String publisherName;
  final String scheduleId;
  final String from;
  final String to;
  final String departureTime;
  final List<int> preferredDays; // 1 = Mon, 7 = Sun
  final String? pickupName;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropName;
  final double? dropLat;
  final double? dropLng;
  final bool autoBook;
  final SubscriptionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.subscriberId,
    required this.subscriberName,
    this.subscriberPhoto,
    required this.publisherId,
    required this.publisherName,
    required this.scheduleId,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.preferredDays,
    this.pickupName,
    this.pickupLat,
    this.pickupLng,
    this.dropName,
    this.dropLat,
    this.dropLng,
    this.autoBook = false,
    this.status = SubscriptionStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == SubscriptionStatus.active;

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return SubscriptionModel(
      id: doc.id,
      subscriberId: d['subscriberId'] ?? '',
      subscriberName: d['subscriberName'] ?? 'Unknown Subscriber',
      subscriberPhoto: d['subscriberPhoto'],
      publisherId: d['publisherId'] ?? '',
      publisherName: d['publisherName'] ?? 'Unknown Publisher',
      scheduleId: d['scheduleId'] ?? '',
      from: d['from'] ?? '',
      to: d['to'] ?? '',
      departureTime: d['departureTime'] ?? '',
      preferredDays: List<int>.from(d['preferredDays'] ?? [1, 2, 3, 4, 5]),
      pickupName: d['pickupName'],
      pickupLat: (d['pickupLat'] as num?)?.toDouble(),
      pickupLng: (d['pickupLng'] as num?)?.toDouble(),
      dropName: d['dropName'],
      dropLat: (d['dropLat'] as num?)?.toDouble(),
      dropLng: (d['dropLng'] as num?)?.toDouble(),
      autoBook: d['autoBook'] ?? false,
      status: SubscriptionStatus.fromString(d['status']),
      createdAt: parseDate(d['createdAt']),
      updatedAt: parseDate(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subscriberId': subscriberId,
      'subscriberName': subscriberName,
      if (subscriberPhoto != null) 'subscriberPhoto': subscriberPhoto,
      'publisherId': publisherId,
      'publisherName': publisherName,
      'scheduleId': scheduleId,
      'from': from,
      'to': to,
      'departureTime': departureTime,
      'preferredDays': preferredDays,
      if (pickupName != null) 'pickupName': pickupName,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (dropName != null) 'dropName': dropName,
      if (dropLat != null) 'dropLat': dropLat,
      if (dropLng != null) 'dropLng': dropLng,
      'autoBook': autoBook,
      'status': status.toDbString(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
