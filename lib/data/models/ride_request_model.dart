import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a booking request from passenger to driver.
enum RequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static RequestStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'pending':
      default:
        return RequestStatus.pending;
    }
  }

  String toDbString() => name;
}

/// Request document representing a passenger's seat booking request.
class RideRequestModel {
  final String id;
  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhoto;
  final int requestedSeats;
  final RequestStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  RideRequestModel({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhoto,
    this.requestedSeats = 1,
    this.status = RequestStatus.pending,
    this.rejectionReason,
    this.createdAt,
    this.respondedAt,
  });

  factory RideRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return RideRequestModel(
      id: doc.id,
      rideId: d['rideId'] ?? '',
      driverId: d['driverId'] ?? '',
      passengerId: d['passengerId'] ?? '',
      passengerName: d['passengerName'] ?? 'Unknown Passenger',
      passengerPhoto: d['passengerPhoto'],
      requestedSeats: (d['requestedSeats'] as num?)?.toInt() ?? 1,
      status: RequestStatus.fromString(d['status']),
      rejectionReason: d['rejectionReason'],
      createdAt: parseDate(d['createdAt']),
      respondedAt: parseDate(d['respondedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      if (passengerPhoto != null) 'passengerPhoto': passengerPhoto,
      'requestedSeats': requestedSeats,
      'status': status.toDbString(),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
    };
  }
}
