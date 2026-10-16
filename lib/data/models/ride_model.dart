import 'package:cloud_firestore/cloud_firestore.dart';
import 'commute_schedule_model.dart';

/// Ride lifecycle status enum.
enum RideStatus {
  pending,
  published,
  full,
  inProgress,
  completed,
  cancelled,
  expired;

  static RideStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'published':
        return RideStatus.published;
      case 'full':
        return RideStatus.full;
      case 'in_progress':
      case 'inprogress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      case 'expired':
        return RideStatus.expired;
      case 'pending':
      default:
        return RideStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case RideStatus.published:
        return 'published';
      case RideStatus.full:
        return 'full';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
      case RideStatus.expired:
        return 'expired';
      case RideStatus.pending:
        return 'pending';
    }
  }

  String get displayName {
    switch (this) {
      case RideStatus.published:
        return 'Open';
      case RideStatus.full:
        return 'Full';
      case RideStatus.inProgress:
        return 'Active';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
      case RideStatus.expired:
        return 'Expired';
      case RideStatus.pending:
        return 'Pending';
    }
  }
}

/// Typed Domain Model for a Pooling Ride document.
class RideModel {
  final String id;
  final String riderId; // Driver UID
  final String postedByName;
  final String from;
  final String to;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final int seats;
  final int remainingSeats;
  final String rideType; // "Car", "Bike"
  final bool allowMultiple;
  final double? distanceKm;
  final double? durationMin;
  final int estimatedCost;
  final DateTime? dateTime;
  final RideStatus status;
  final String? driverUpi;
  final String? paymentStatus;
  final String? acceptedBy;
  final List<String> acceptedByList;
  final String? rideCode;
  final DateTime? createdAt;

  // Hybrid & recurring commute extensions
  final String? scheduleId;
  final String? occurrenceDate; // "YYYY-MM-DD"
  final RideVisibility visibility;
  final List<RouteWaypoint> waypoints;
  final String? notes;
  final double? maxDetourKm;

  RideModel({
    required this.id,
    required this.riderId,
    required this.postedByName,
    required this.from,
    required this.to,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.seats,
    required this.remainingSeats,
    this.rideType = 'Car',
    this.allowMultiple = true,
    this.distanceKm,
    this.durationMin,
    required this.estimatedCost,
    this.dateTime,
    this.status = RideStatus.pending,
    this.driverUpi,
    this.paymentStatus = 'pending',
    this.acceptedBy,
    this.acceptedByList = const [],
    this.rideCode,
    this.createdAt,
    this.scheduleId,
    this.occurrenceDate,
    this.visibility = RideVisibility.publicVisibility,
    this.waypoints = const [],
    this.notes,
    this.maxDetourKm,
  });

  bool get isFull => remainingSeats <= 0;
  bool get canBook =>
      !isFull &&
      (status == RideStatus.pending || status == RideStatus.published);

  bool get isRecurringOccurrence => scheduleId != null;

  /// Validates ride creation inputs.
  static String? validateInputs({
    required String from,
    required String to,
    required int seats,
    required DateTime? dateTime,
    required double? fromLat,
    required double? toLat,
  }) {
    if (from.trim().isEmpty) return 'Pickup location is required.';
    if (to.trim().isEmpty) return 'Destination location is required.';
    if (from.trim().toLowerCase() == to.trim().toLowerCase()) {
      return 'Pickup and destination must be different.';
    }
    if (fromLat == null || toLat == null) {
      return 'Valid map coordinates are required for both locations.';
    }
    if (seats <= 0) return 'Available seats must be at least 1.';
    if (seats > 8) return 'Maximum seats allowed is 8.';
    if (dateTime == null) return 'Departure date and time is required.';
    if (dateTime.isBefore(DateTime.now())) {
      return 'Departure time must be in the future.';
    }
    return null;
  }

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
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

    return RideModel(
      id: doc.id,
      riderId: d['riderId'] ?? '',
      postedByName: d['postedByName'] ?? 'Unknown Driver',
      from: d['from'] ?? '',
      to: d['to'] ?? '',
      fromLat: (d['from_lat'] as num?)?.toDouble() ?? 0.0,
      fromLng: (d['from_lng'] as num?)?.toDouble() ?? 0.0,
      toLat: (d['to_lat'] as num?)?.toDouble() ?? 0.0,
      toLng: (d['to_lng'] as num?)?.toDouble() ?? 0.0,
      seats: (d['seats'] as num?)?.toInt() ?? 1,
      remainingSeats:
          (d['remainingSeats'] as num?)?.toInt() ??
          (d['seats'] as num?)?.toInt() ??
          1,
      rideType: d['rideType'] ?? 'Car',
      allowMultiple: d['allowMultiple'] ?? true,
      distanceKm: (d['distance_km'] as num?)?.toDouble(),
      durationMin: (d['duration_min'] as num?)?.toDouble(),
      estimatedCost: (d['estimatedCost'] as num?)?.toInt() ?? 0,
      dateTime: parseDate(d['dateTime']),
      status: RideStatus.fromString(d['status']),
      driverUpi: d['driverUPI'],
      paymentStatus: d['paymentStatus'] ?? 'pending',
      acceptedBy: d['acceptedBy'],
      acceptedByList: List<String>.from(d['acceptedByList'] ?? []),
      rideCode: d['rideCode'],
      createdAt: parseDate(d['timestamp']),
      scheduleId: d['scheduleId'],
      occurrenceDate: d['occurrenceDate'],
      visibility: RideVisibility.fromString(d['visibility']),
      waypoints: waypointsList,
      notes: d['notes'],
      maxDetourKm: (d['maxDetourKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'postedByName': postedByName,
      'from': from,
      'to': to,
      'from_lat': fromLat,
      'from_lng': fromLng,
      'to_lat': toLat,
      'to_lng': toLng,
      'seats': seats,
      'remainingSeats': remainingSeats,
      'rideType': rideType,
      'allowMultiple': allowMultiple,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (durationMin != null) 'duration_min': durationMin,
      'estimatedCost': estimatedCost,
      if (dateTime != null) 'dateTime': Timestamp.fromDate(dateTime!),
      'status': status.toDbString(),
      if (driverUpi != null) 'driverUPI': driverUpi,
      'paymentStatus': paymentStatus,
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
      'acceptedByList': acceptedByList,
      if (rideCode != null) 'rideCode': rideCode,
      if (scheduleId != null) 'scheduleId': scheduleId,
      if (occurrenceDate != null) 'occurrenceDate': occurrenceDate,
      'visibility': visibility.toDbString(),
      if (waypoints.isNotEmpty)
        'waypoints': waypoints.map((w) => w.toMap()).toList(),
      if (notes != null) 'notes': notes,
      if (maxDetourKm != null) 'maxDetourKm': maxDetourKm,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
