import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_request_model.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

/// Result wrapper for booking operations.
class BookingResult {
  final bool success;
  final String? message;
  final String? requestId;
  final String? bookingId;

  BookingResult._({
    required this.success,
    this.message,
    this.requestId,
    this.bookingId,
  });

  factory BookingResult.ok({
    String? message,
    String? requestId,
    String? bookingId,
  }) => BookingResult._(
    success: true,
    message: message,
    requestId: requestId,
    bookingId: bookingId,
  );

  factory BookingResult.fail(String error) =>
      BookingResult._(success: false, message: error);
}

/// Repository managing atomic seat allocation, booking requests,
/// driver approvals, and lifecycle state transitions.
class BookingRepository {
  final FirebaseFirestore? _customFirestore;
  final NotificationRepository _notifRepo;

  BookingRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notifRepo,
  }) : _customFirestore = firestore,
       _notifRepo = notifRepo ?? NotificationRepository(firestore: firestore);

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference get _ridesRef => _firestore.collection('rides');
  CollectionReference get _requestsRef => _firestore.collection('rideRequests');
  CollectionReference get _bookingsRef => _firestore.collection('bookings');

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

    // Check if user is already confirmed
    final acceptedList = List<String>.from(rideData['acceptedByList'] ?? []);
    if (acceptedList.contains(passengerId)) {
      return BookingResult.fail('You already have a confirmed seat on this ride.');
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

    // Notify the driver
    _notifRepo.send(
      recipientId: driverId,
      title: 'New Ride Request! 🙋',
      body:
          '$passengerName requested $requestedSeats seat(s) on your ride to ${rideData['to']}.',
      type: AppNotificationType.bookingRequest,
      relatedId: rideId,
    );

    return BookingResult.ok(
      message: 'Booking request sent to driver!',
      requestId: docRef.id,
    );
  }

  /// Driver approves a pending booking request.
  ///
  /// Uses a Firestore transaction to atomically decrement seats
  /// and update the request, booking, and ride documents, preventing overbooking.
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
        String? rideCode = rideData['rideCode']?.toString();
        if (rideCode == null || rideCode.isEmpty) {
          rideCode = (1000 + Random.secure().nextInt(9000)).toString();
          rideUpdates['rideCode'] = rideCode;
        }

        // Execute atomic updates
        txn.update(reqRef, {
          'status': 'approved',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        txn.update(rideRef, rideUpdates);

        // Create authoritative Booking document
        final bookingRef = _bookingsRef.doc();
        txn.set(bookingRef, {
          'rideId': rideId,
          if (rideData['scheduleId'] != null)
            'scheduleId': rideData['scheduleId'],
          'driverId': driverId,
          'passengerId': passengerId,
          'passengerName': reqData['passengerName'] ?? 'Passenger',
          if (reqData['passengerPhoto'] != null)
            'passengerPhoto': reqData['passengerPhoto'],
          'seatsBooked': seatsToDeduct,
          'from': rideData['from'],
          'to': rideData['to'],
          if (rideData['dateTime'] != null)
            'rideDateTime': rideData['dateTime'],
          'cost': (rideData['estimatedCost'] as num?)?.toInt() ?? 0,
          'status': 'confirmed',
          'requestId': requestId,
          'boardingPin': rideCode,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Notify passenger
        _notifRepo.send(
          recipientId: passengerId,
          title: 'Booking Approved! ✅',
          body:
              'Your request for ${rideData['from']} → ${rideData['to']} was approved. Boarding PIN: $rideCode',
          type: AppNotificationType.bookingApproved,
          relatedId: rideId,
        );

        return BookingResult.ok(
          message: 'Request approved successfully.',
          bookingId: bookingRef.id,
        );
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

    final passengerId = data['passengerId'] as String;

    await reqRef.update({
      'status': 'rejected',
      if (reason != null) 'rejectionReason': reason,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    _notifRepo.send(
      recipientId: passengerId,
      title: 'Booking Request Declined',
      body: reason ?? 'Your request to join the ride was declined.',
      type: AppNotificationType.bookingRejected,
      relatedId: data['rideId'],
    );

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

  /// Cancels a confirmed booking and restores seats atomically.
  Future<BookingResult> cancelBooking({
    required String bookingId,
    required String userId,
    String? reason,
  }) async {
    final bookingRef = _bookingsRef.doc(bookingId);

    try {
      return await _firestore.runTransaction<BookingResult>((txn) async {
        final bSnap = await txn.get(bookingRef);
        if (!bSnap.exists) return BookingResult.fail('Booking not found.');

        final bData = bSnap.data() as Map<String, dynamic>;
        final passengerId = bData['passengerId'] as String;
        final driverId = bData['driverId'] as String;

        if (userId != passengerId && userId != driverId) {
          return BookingResult.fail('Unauthorized.');
        }

        if (bData['status'] == 'cancelled') {
          return BookingResult.fail('Booking already cancelled.');
        }

        final rideId = bData['rideId'] as String;
        final rideRef = _ridesRef.doc(rideId);
        final rideSnap = await txn.get(rideRef);

        if (rideSnap.exists) {
          final rideData = rideSnap.data() as Map<String, dynamic>;
          final seatsToRestore = (bData['seatsBooked'] as num?)?.toInt() ?? 1;
          final currentRem =
              ((rideData['remainingSeats'] ?? 0) as num).toInt();
          final totalSeats = ((rideData['seats'] ?? 1) as num).toInt();
          final newRem = min(totalSeats, currentRem + seatsToRestore);

          final acceptedList = List<String>.from(
            rideData['acceptedByList'] ?? [],
          );
          acceptedList.remove(passengerId);

          final rideUpdates = <String, dynamic>{
            'remainingSeats': newRem,
            'acceptedByList': acceptedList,
          };
          if (rideData['status'] == 'full') {
            rideUpdates['status'] = 'published';
          }
          txn.update(rideRef, rideUpdates);
        }

        txn.update(bookingRef, {
          'status': 'cancelled',
          'cancelledBy': userId == driverId ? 'driver' : 'passenger',
          if (reason != null) 'cancellationReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Notify counterpart
        final notifyId = userId == driverId ? passengerId : driverId;
        _notifRepo.send(
          recipientId: notifyId,
          title: 'Ride Booking Cancelled ⚠️',
          body: 'A seat booking for ride ${bData['from']} → ${bData['to']} was cancelled.',
          type: AppNotificationType.bookingCancelled,
          relatedId: rideId,
        );

        return BookingResult.ok(message: 'Booking cancelled successfully.');
      });
    } catch (e) {
      return BookingResult.fail('Failed to cancel booking: $e');
    }
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

  /// Stream of confirmed bookings for a passenger.
  Stream<List<BookingModel>> streamPassengerBookings(String passengerId) {
    return _bookingsRef
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => BookingModel.fromFirestore(d)).toList(),
        );
  }

  /// Stream of confirmed passengers/bookings for a ride occurrence.
  Stream<List<BookingModel>> streamRideBookings(String rideId) {
    return _bookingsRef
        .where('rideId', isEqualTo: rideId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => BookingModel.fromFirestore(d)).toList(),
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
