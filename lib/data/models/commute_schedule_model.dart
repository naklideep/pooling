import 'package:cloud_firestore/cloud_firestore.dart';

/// Commute Schedule status enum.
enum CommuteStatus {
  active,
  paused,
  ended;

  static CommuteStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'paused':
        return CommuteStatus.paused;
      case 'ended':
        return CommuteStatus.ended;
      case 'active':
      default:
        return CommuteStatus.active;
    }
  }

  String toDbString() => name;
}

/// Ride visibility for pooling discovery.
enum RideVisibility {
  publicVisibility,
  subscribersOnly,
  inviteOnly;

  static RideVisibility fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'subscribers_only':
      case 'subscribersonly':
        return RideVisibility.subscribersOnly;
      case 'invite_only':
      case 'inviteonly':
        return RideVisibility.inviteOnly;
      case 'public':
      default:
        return RideVisibility.publicVisibility;
    }
  }

  String toDbString() {
    switch (this) {
      case RideVisibility.subscribersOnly:
        return 'subscribers_only';
      case RideVisibility.inviteOnly:
        return 'invite_only';
      case RideVisibility.publicVisibility:
        return 'public';
    }
  }

  String get displayName {
    switch (this) {
      case RideVisibility.subscribersOnly:
        return 'Subscribers Only';
      case RideVisibility.inviteOnly:
        return 'Invite Only';
      case RideVisibility.publicVisibility:
        return 'Public';
    }
  }
}

/// Represents an intermediate stop / waypoint along a commute route.
class RouteWaypoint {
  final String name;
  final double lat;
  final double lng;

  const RouteWaypoint({
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory RouteWaypoint.fromMap(Map<String, dynamic> map) {
    return RouteWaypoint(
      name: map['name'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'lat': lat, 'lng': lng};
}

/// Domain model for recurring commute schedules created by publishers.
class CommuteScheduleModel {
  final String id;
  final String publisherId;
  final String publisherName;
  final String? publisherPhoto;
  final String from;
  final String to;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final List<RouteWaypoint> waypoints;
  final String departureTime; // "HH:mm" (24-hour format, e.g. "09:00")
  final double? estimatedDurationMin;
  final double? distanceKm;
  final List<int> daysOfWeek; // 1 = Mon, 7 = Sun
  final int seats;
  final int estimatedCostPerSeat;
  final String? vehicleModel;
  final String? vehicleNumber;
  final String rideType; // "Car", "Bike"
  final RideVisibility visibility;
  final CommuteStatus status;
  final double maxDetourKm;
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final String timezone;
  final int subscriberCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommuteScheduleModel({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    this.publisherPhoto,
    required this.from,
    required this.to,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.waypoints = const [],
    required this.departureTime,
    this.estimatedDurationMin,
    this.distanceKm,
    required this.daysOfWeek,
    required this.seats,
    required this.estimatedCostPerSeat,
    this.vehicleModel,
    this.vehicleNumber,
    this.rideType = 'Car',
    this.visibility = RideVisibility.publicVisibility,
    this.status = CommuteStatus.active,
    this.maxDetourKm = 3.0,
    this.notes,
    this.startDate,
    this.endDate,
    this.timezone = 'Asia/Kolkata',
    this.subscriberCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == CommuteStatus.active;

  /// Returns user-friendly summary of recurring days, e.g. "Mon - Fri" or "Mon, Wed, Fri"
  String get daysSummary {
    if (daysOfWeek.length == 7) return 'Every day';
    if (daysOfWeek.length == 5 &&
        daysOfWeek.contains(1) &&
        daysOfWeek.contains(2) &&
        daysOfWeek.contains(3) &&
        daysOfWeek.contains(4) &&
        daysOfWeek.contains(5)) {
      return 'Weekdays (Mon-Fri)';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(daysOfWeek)..sort();
    return sorted.map((d) => dayNames[(d - 1) % 7]).join(', ');
  }

  factory CommuteScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final rawWps = d['waypoints'] as List<dynamic>? ?? [];
    final waypointsList = rawWps
        .whereType<Map<String, dynamic>>()
        .map((m) => RouteWaypoint.fromMap(m))
        .toList();

    return CommuteScheduleModel(
      id: doc.id,
      publisherId: d['publisherId'] ?? '',
      publisherName: d['publisherName'] ?? 'Unknown Publisher',
      publisherPhoto: d['publisherPhoto'],
      from: d['from'] ?? '',
      to: d['to'] ?? '',
      fromLat: (d['fromLat'] as num?)?.toDouble() ?? 0.0,
      fromLng: (d['fromLng'] as num?)?.toDouble() ?? 0.0,
      toLat: (d['toLat'] as num?)?.toDouble() ?? 0.0,
      toLng: (d['toLng'] as num?)?.toDouble() ?? 0.0,
      waypoints: waypointsList,
      departureTime: d['departureTime'] ?? '09:00',
      estimatedDurationMin: (d['estimatedDurationMin'] as num?)?.toDouble(),
      distanceKm: (d['distanceKm'] as num?)?.toDouble(),
      daysOfWeek: List<int>.from(d['daysOfWeek'] ?? [1, 2, 3, 4, 5]),
      seats: (d['seats'] as num?)?.toInt() ?? 1,
      estimatedCostPerSeat: (d['estimatedCostPerSeat'] as num?)?.toInt() ?? 0,
      vehicleModel: d['vehicleModel'],
      vehicleNumber: d['vehicleNumber'],
      rideType: d['rideType'] ?? 'Car',
      visibility: RideVisibility.fromString(d['visibility']),
      status: CommuteStatus.fromString(d['status']),
      maxDetourKm: (d['maxDetourKm'] as num?)?.toDouble() ?? 3.0,
      notes: d['notes'],
      startDate: parseDate(d['startDate']),
      endDate: parseDate(d['endDate']),
      timezone: d['timezone'] ?? 'Asia/Kolkata',
      subscriberCount: (d['subscriberCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(d['createdAt']),
      updatedAt: parseDate(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publisherId': publisherId,
      'publisherName': publisherName,
      if (publisherPhoto != null) 'publisherPhoto': publisherPhoto,
      'from': from,
      'to': to,
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'departureTime': departureTime,
      if (estimatedDurationMin != null)
        'estimatedDurationMin': estimatedDurationMin,
      if (distanceKm != null) 'distanceKm': distanceKm,
      'daysOfWeek': daysOfWeek,
      'seats': seats,
      'estimatedCostPerSeat': estimatedCostPerSeat,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      'rideType': rideType,
      'visibility': visibility.toDbString(),
      'status': status.toDbString(),
      'maxDetourKm': maxDetourKm,
      if (notes != null) 'notes': notes,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'timezone': timezone,
      'subscriberCount': subscriberCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
