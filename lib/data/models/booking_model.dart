import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle status for a confirmed or requested seat booking.
enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  waitlisted,
  noShow;

  static BookingStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'waitlisted':
        return BookingStatus.waitlisted;
      case 'no_show':
      case 'noshow':
        return BookingStatus.noShow;
      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case BookingStatus.noShow:
        return 'no_show';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.waitlisted:
        return 'Waitlisted';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }
}

/// Authoritative seat reservation and passenger participation model.
class BookingModel {
  final String id;
  final String rideId;
  final String? scheduleId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhoto;
  final int seatsBooked;
  final String? from;
  final String? to;
  final DateTime? rideDateTime;
  final String? pickupName;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropName;
  final double? dropLat;
  final double? dropLng;
  final int cost;
  final BookingStatus status;
  final String? invitationId;
  final String? requestId;
  final String? boardingPin;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.rideId,
    this.scheduleId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhoto,
    this.seatsBooked = 1,
    this.from,
    this.to,
    this.rideDateTime,
    this.pickupName,
    this.pickupLat,
    this.pickupLng,
    this.dropName,
    this.dropLat,
    this.dropLng,
    this.cost = 0,
    this.status = BookingStatus.confirmed,
    this.invitationId,
    this.requestId,
    this.boardingPin,
    this.cancellationReason,
    this.cancelledBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isCancelled => status == BookingStatus.cancelled;

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return BookingModel(
      id: doc.id,
      rideId: d['rideId'] ?? '',
      scheduleId: d['scheduleId'],
      driverId: d['driverId'] ?? '',
      passengerId: d['passengerId'] ?? '',
      passengerName: d['passengerName'] ?? 'Unknown Passenger',
      passengerPhoto: d['passengerPhoto'],
      seatsBooked: (d['seatsBooked'] as num?)?.toInt() ?? 1,
      from: d['from'],
      to: d['to'],
      rideDateTime: parseDate(d['rideDateTime'] ?? d['dateTime']),
      pickupName: d['pickupName'],
      pickupLat: (d['pickupLat'] as num?)?.toDouble(),
      pickupLng: (d['pickupLng'] as num?)?.toDouble(),
      dropName: d['dropName'],
      dropLat: (d['dropLat'] as num?)?.toDouble(),
      dropLng: (d['dropLng'] as num?)?.toDouble(),
      cost: (d['cost'] as num?)?.toInt() ?? 0,
      status: BookingStatus.fromString(d['status']),
      invitationId: d['invitationId'],
      requestId: d['requestId'],
      boardingPin: d['boardingPin'],
      cancellationReason: d['cancellationReason'],
      cancelledBy: d['cancelledBy'],
      createdAt: parseDate(d['createdAt']),
      updatedAt: parseDate(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      if (scheduleId != null) 'scheduleId': scheduleId,
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      if (passengerPhoto != null) 'passengerPhoto': passengerPhoto,
      'seatsBooked': seatsBooked,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (rideDateTime != null) 'rideDateTime': Timestamp.fromDate(rideDateTime!),
      if (pickupName != null) 'pickupName': pickupName,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (dropName != null) 'dropName': dropName,
      if (dropLat != null) 'dropLat': dropLat,
      if (dropLng != null) 'dropLng': dropLng,
      'cost': cost,
      'status': status.toDbString(),
      if (invitationId != null) 'invitationId': invitationId,
      if (requestId != null) 'requestId': requestId,
      if (boardingPin != null) 'boardingPin': boardingPin,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
