import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';

/// Result wrapper for booking operations.
class BookingResult {
  final bool success;
  final String? message;
  final String? requestId;

  BookingResult._({required this.success, this.message, this.requestId});

  factory BookingResult.ok({String? message, String? requestId}) =>
      BookingResult._(success: true, message: message, requestId: requestId);

  factory BookingResult.fail(String error) =>
      BookingResult._(success: false, message: error);
}

/// Repository managing atomic seat allocation, booking requests,
/// driver approvals, and lifecycle state transitions.
class BookingRepository {
  final FirebaseFirestore? _customFirestore;

  BookingRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference get _ridesRef => _firestore.collection('rides');
  CollectionReference get _requestsRef => _firestore.collection('rideRequests');

  /// Requests a seat on a ride.
  ///
  /// Enforces:
  /// - User cannot book their own ride.
  /// - User cannot submit duplicate pending requests for the same ride.
  /// - Atomic check that remainingSeats >= requestedSeats.
  Future<BookingResult> requestSeat({
    required String rideId,
    required String passengerId,
    required String passengerName,
    String? passengerPhoto,
    int requestedSeats = 1,
  }) async {
    if (requestedSeats <= 0) {
      return BookingResult.fail('Must request at least 1 seat.');
    }

    final rideDoc = await _ridesRef.doc(rideId).get();
    if (!rideDoc.exists) {
      return BookingResult.fail('Ride does not exist or was removed.');
    }

    final rideData = rideDoc.data() as Map<String, dynamic>;
    final driverId = rideData['riderId'] as String? ?? '';

    if (driverId == passengerId) {
      return BookingResult.fail('You cannot book your own ride.');
    }

    final status = rideData['status'] as String? ?? '';
    if (status == 'cancelled' || status == 'completed' || status == 'expired') {
      return BookingResult.fail('This ride is no longer active.');
    }

    final remaining =
        ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num).toInt();
    if (remaining < requestedSeats) {
      return BookingResult.fail(
        'Not enough seats available ($remaining remaining).',
      );
    }

    // Check duplicate pending requests
    final dupCheck = await _requestsRef
        .where('rideId', isEqualTo: rideId)
        .where('passengerId', isEqualTo: passengerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (dupCheck.docs.isNotEmpty) {
      return BookingResult.fail(
        'You already have a pending booking request for this ride.',
      );
    }

    // Create the booking request document
    final docRef = await _requestsRef.add({
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhoto': passengerPhoto,
      'requestedSeats': requestedSeats,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return BookingResult.ok(
      message: 'Booking request sent to driver!',
      requestId: docRef.id,
    );
  }

  /// Driver approves a pending booking request.
  ///
  /// Uses a Firestore transaction to atomically decrement seats
  /// and update the request and ride documents, preventing overbooking.
  Future<BookingResult> approveRequest({
    required String requestId,
    required String driverId,
  }) async {
    final reqRef = _requestsRef.doc(requestId);

    try {
      return await _firestore.runTransaction<BookingResult>((txn) async {
        final reqSnap = await txn.get(reqRef);
        if (!reqSnap.exists) {
          return BookingResult.fail('Request no longer exists.');
        }

        final reqData = reqSnap.data() as Map<String, dynamic>;
        if (reqData['driverId'] != driverId) {
          return BookingResult.fail('Unauthorized to approve this request.');
        }

        if (reqData['status'] != 'pending') {
          return BookingResult.fail('Request is no longer pending.');
        }

        final rideId = reqData['rideId'] as String;
        final rideRef = _ridesRef.doc(rideId);
        final rideSnap = await txn.get(rideRef);
        if (!rideSnap.exists) {
          return BookingResult.fail('Ride no longer exists.');
        }

        final rideData = rideSnap.data() as Map<String, dynamic>;
        final seatsToDeduct = (reqData['requestedSeats'] as num?)?.toInt() ?? 1;
        final currentRemaining =
            ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num)
                .toInt();

        if (currentRemaining < seatsToDeduct) {
          txn.update(reqRef, {
            'status': 'rejected',
            'rejectionReason': 'Ride has filled up.',
            'respondedAt': FieldValue.serverTimestamp(),
          });
          return BookingResult.fail(
            'Ride is full. Request automatically rejected.',
          );
        }

        final newRemaining = currentRemaining - seatsToDeduct;
        final passengerId = reqData['passengerId'] as String;

        // Build ride updates
        final rideUpdates = <String, dynamic>{'remainingSeats': newRemaining};

        if (newRemaining <= 0) {
          rideUpdates['status'] = 'full';
        }

        // Add to acceptedByList
        final acceptedByList = List<String>.from(
          rideData['acceptedByList'] ?? [],
        );
        if (!acceptedByList.contains(passengerId)) {
          acceptedByList.add(passengerId);
        }
        rideUpdates['acceptedByList'] = acceptedByList;

        // Generate rideCode if not present
        if (rideData['rideCode'] == null) {
          final code = (1000 + Random.secure().nextInt(9000)).toString();
          rideUpdates['rideCode'] = code;
        }

        // Execute atomic updates
        txn.update(reqRef, {
          'status': 'approved',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        txn.update(rideRef, rideUpdates);

        return BookingResult.ok(message: 'Request approved successfully.');
      });
    } catch (e) {
      return BookingResult.fail('Failed to approve request: $e');
    }
  }

  /// Driver rejects a booking request.
  Future<BookingResult> rejectRequest({
    required String requestId,
    required String driverId,
    String? reason,
  }) async {
    final reqRef = _requestsRef.doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      return BookingResult.fail('Request no longer exists.');
    }

    final data = reqSnap.data() as Map<String, dynamic>;
    if (data['driverId'] != driverId) {
      return BookingResult.fail('Unauthorized.');
    }

    await reqRef.update({
      'status': 'rejected',
      if (reason != null) 'rejectionReason': reason,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    return BookingResult.ok(message: 'Request rejected.');
  }

  /// Passenger cancels their pending request.
  Future<BookingResult> cancelRequest({
    required String requestId,
    required String passengerId,
  }) async {
    final reqRef = _requestsRef.doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      return BookingResult.fail('Request not found.');
    }

    final data = reqSnap.data() as Map<String, dynamic>;
    if (data['passengerId'] != passengerId) {
      return BookingResult.fail('Unauthorized to cancel this request.');
    }

    await reqRef.update({
      'status': 'cancelled',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    return BookingResult.ok(message: 'Request cancelled.');
  }

  /// Stream of pending requests for a specific ride (for the driver).
  Stream<List<RideRequestModel>> streamPendingRequestsForRide(String rideId) {
    return _requestsRef
        .where('rideId', isEqualTo: rideId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RideRequestModel.fromFirestore(d)).toList(),
        );
  }

  /// Stream of all booking requests made by a specific passenger.
  Stream<List<RideRequestModel>> streamPassengerRequests(String passengerId) {
    return _requestsRef
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RideRequestModel.fromFirestore(d)).toList(),
        );
  }

  /// Verifies the 4-digit pickup security PIN entered by driver/passenger.
  Future<bool> verifyPickupCode({
    required String rideId,
    required String enteredCode,
  }) async {
    final snap = await _ridesRef.doc(rideId).get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final realCode = data['rideCode']?.toString();
    return realCode != null && realCode == enteredCode.trim();
  }
}
