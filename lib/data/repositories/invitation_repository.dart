import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invitation_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class InvitationResult {
  final bool success;
  final String? message;
  final String? invitationId;
  final String? bookingId;

  const InvitationResult._({
    required this.success,
    this.message,
    this.invitationId,
    this.bookingId,
  });

  factory InvitationResult.ok({
    String? message,
    String? invitationId,
    String? bookingId,
  }) => InvitationResult._(
    success: true,
    message: message,
    invitationId: invitationId,
    bookingId: bookingId,
  );

  factory InvitationResult.fail(String error) =>
      InvitationResult._(success: false, message: error);
}

/// Repository for creating, sending, accepting, and tracking ride invitations.
class InvitationRepository {
  final FirebaseFirestore? _customFirestore;
  final NotificationRepository _notifRepo;

  InvitationRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notifRepo,
  }) : _customFirestore = firestore,
       _notifRepo = notifRepo ?? NotificationRepository(firestore: firestore);

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference get _invitationsRef =>
      _firestore.collection('invitations');
  CollectionReference get _ridesRef => _firestore.collection('rides');
  CollectionReference get _bookingsRef => _firestore.collection('bookings');
  CollectionReference get _usersRef => _firestore.collection('users');

  /// Generates a random alphanumeric shareable invitation code.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'POOL-$code';
  }

  /// Creates and sends an invitation to a rider.
  Future<InvitationResult> sendInvitation({
    required String publisherId,
    required String publisherName,
    String? publisherPhoto,
    String? recipientId,
    String? recipientEmail,
    String? recipientName,
    String? recipientPhone,
    String? rideId,
    String? scheduleId,
    required String from,
    required String to,
    DateTime? rideDateTime,
    InvitationScope scope = InvitationScope.occurrence,
    int seatsOffered = 1,
    Duration validDuration = const Duration(hours: 48),
  }) async {
    try {
      // Validate recipient is not the publisher
      if (recipientId != null && recipientId == publisherId) {
        return InvitationResult.fail('You cannot invite yourself.');
      }

      // Check if pending invite already exists for this recipient on this ride
      if (recipientId != null && rideId != null) {
        final existing = await _invitationsRef
            .where('rideId', isEqualTo: rideId)
            .where('recipientId', isEqualTo: recipientId)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          return InvitationResult.fail(
            'A pending invitation was already sent to this rider for this ride.',
          );
        }
      }

      final expiresAt = DateTime.now().add(validDuration);
      final inviteCode = _generateInviteCode();
      final docRef = _invitationsRef.doc();

      final invitation = InvitationModel(
        id: docRef.id,
        publisherId: publisherId,
        publisherName: publisherName,
        publisherPhoto: publisherPhoto,
        recipientId: recipientId,
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        rideId: rideId,
        scheduleId: scheduleId,
        from: from,
        to: to,
        rideDateTime: rideDateTime,
        scope: scope,
        inviteCode: inviteCode,
        status: InvitationStatus.pending,
        seatsOffered: seatsOffered,
        expiresAt: expiresAt,
        createdAt: DateTime.now(),
      );

      await docRef.set(invitation.toMap());

      // Send notification if recipientId is provided
      if (recipientId != null) {
        _notifRepo.send(
          recipientId: recipientId,
          title: 'Ride Invitation from $publisherName 🚗',
          body:
              '$publisherName invited you to join their ride from $from to $to.',
          type: AppNotificationType.invitationReceived,
          relatedId: docRef.id,
        );
      }

      return InvitationResult.ok(
        invitationId: docRef.id,
        message: 'Invitation sent successfully!',
      );
    } catch (e) {
      return InvitationResult.fail('Failed to send invitation: $e');
    }
  }

  /// Searches users in the database by name or email.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final cleanQ = query.trim();

    try {
      final snap = await _usersRef
          .where('name', isGreaterThanOrEqualTo: cleanQ)
          .where('name', isLessThanOrEqualTo: '$cleanQ\uf8ff')
          .limit(10)
          .get();

      return snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Atomically accepts an invitation and books the seat.
  Future<InvitationResult> acceptInvitation({
    required String invitationId,
    required String acceptingUserId,
    required String acceptingUserName,
    String? acceptingUserPhoto,
  }) async {
    final invRef = _invitationsRef.doc(invitationId);

    try {
      return await _firestore.runTransaction<InvitationResult>((txn) async {
        final invSnap = await txn.get(invRef);
        if (!invSnap.exists) {
          return InvitationResult.fail('Invitation not found.');
        }

        final invData = invSnap.data() as Map<String, dynamic>;
        final currentStatus = invData['status'] as String? ?? '';
        if (currentStatus != 'pending') {
          return InvitationResult.fail(
            'This invitation is no longer pending ($currentStatus).',
          );
        }

        // Verify recipient
        final recipientId = invData['recipientId'] as String?;
        if (recipientId != null && recipientId != acceptingUserId) {
          return InvitationResult.fail('Unauthorized to accept this invitation.');
        }

        // Verify expiry
        final expiresAtTs = invData['expiresAt'] as Timestamp?;
        if (expiresAtTs != null &&
            DateTime.now().isAfter(expiresAtTs.toDate())) {
          txn.update(invRef, {'status': 'expired'});
          return InvitationResult.fail('This invitation has expired.');
        }

        final rideId = invData['rideId'] as String?;
        if (rideId == null) {
          // Schedule-level invite without specific ride
          txn.update(invRef, {
            'status': 'accepted',
            'recipientId': acceptingUserId,
            'respondedAt': FieldValue.serverTimestamp(),
          });
          return InvitationResult.ok(message: 'Commute invitation accepted.');
        }

        final rideRef = _ridesRef.doc(rideId);
        final rideSnap = await txn.get(rideRef);
        if (!rideSnap.exists) {
          return InvitationResult.fail('The associated ride no longer exists.');
        }

        final rideData = rideSnap.data() as Map<String, dynamic>;
        final rideStatus = rideData['status'] as String? ?? '';
        if (rideStatus == 'cancelled' ||
            rideStatus == 'completed' ||
            rideStatus == 'in_progress') {
          return InvitationResult.fail('This ride is no longer active.');
        }

        final seatsOffered = (invData['seatsOffered'] as num?)?.toInt() ?? 1;
        final currentRemaining =
            ((rideData['remainingSeats'] ?? rideData['seats'] ?? 0) as num)
                .toInt();

        if (currentRemaining < seatsOffered) {
          return InvitationResult.fail(
            'Sorry, no seats remain available on this ride.',
          );
        }

        // Check if user is already booked
        final acceptedByList = List<String>.from(
          rideData['acceptedByList'] ?? [],
        );
        if (acceptedByList.contains(acceptingUserId)) {
          return InvitationResult.fail(
            'You are already booked on this ride.',
          );
        }

        final newRemaining = currentRemaining - seatsOffered;
        acceptedByList.add(acceptingUserId);

        // Security PIN
        String? rideCode = rideData['rideCode']?.toString();
        if (rideCode == null || rideCode.isEmpty) {
          rideCode = (1000 + Random.secure().nextInt(9000)).toString();
        }

        // Update Ride atomically
        final rideUpdates = <String, dynamic>{
          'remainingSeats': newRemaining,
          'acceptedByList': acceptedByList,
          'rideCode': rideCode,
        };
        if (newRemaining <= 0) {
          rideUpdates['status'] = 'full';
        }
        txn.update(rideRef, rideUpdates);

        // Update Invitation
        txn.update(invRef, {
          'status': 'accepted',
          'recipientId': acceptingUserId,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        // Create Booking record
        final bookingRef = _bookingsRef.doc();
        final bookingData = <String, dynamic>{
          'rideId': rideId,
          if (invData['scheduleId'] != null)
            'scheduleId': invData['scheduleId'],
          'driverId': invData['publisherId'],
          'passengerId': acceptingUserId,
          'passengerName': acceptingUserName,
          if (acceptingUserPhoto != null)
            'passengerPhoto': acceptingUserPhoto,
          'seatsBooked': seatsOffered,
          'from': invData['from'],
          'to': invData['to'],
          if (rideData['dateTime'] != null)
            'rideDateTime': rideData['dateTime'],
          'cost': (rideData['estimatedCost'] as num?)?.toInt() ?? 0,
          'status': 'confirmed',
          'invitationId': invitationId,
          'boardingPin': rideCode,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        txn.set(bookingRef, bookingData);

        return InvitationResult.ok(
          bookingId: bookingRef.id,
          message: 'Invitation accepted! Seat confirmed.',
        );
      });
    } catch (e) {
      return InvitationResult.fail('Failed to accept invitation: $e');
    }
  }

  /// Declines a direct invitation.
  Future<InvitationResult> declineInvitation({
    required String invitationId,
    required String decliningUserId,
  }) async {
    try {
      final doc = await _invitationsRef.doc(invitationId).get();
      if (!doc.exists) return InvitationResult.fail('Invitation not found.');

      final data = doc.data() as Map<String, dynamic>;
      final publisherId = data['publisherId'] as String;

      await _invitationsRef.doc(invitationId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Notify publisher
      _notifRepo.send(
        recipientId: publisherId,
        title: 'Invitation Declined',
        body: 'A rider declined your invitation for ${data['from']} → ${data['to']}.',
        type: AppNotificationType.invitationDeclined,
        relatedId: invitationId,
      );

      return InvitationResult.ok(message: 'Invitation declined.');
    } catch (e) {
      return InvitationResult.fail('Failed to decline: $e');
    }
  }

  /// Revokes an invitation (by publisher).
  Future<InvitationResult> revokeInvitation({
    required String invitationId,
    required String publisherId,
  }) async {
    try {
      final doc = await _invitationsRef.doc(invitationId).get();
      if (!doc.exists) return InvitationResult.fail('Invitation not found.');

      final data = doc.data() as Map<String, dynamic>;
      if (data['publisherId'] != publisherId) {
        return InvitationResult.fail('Unauthorized.');
      }

      await _invitationsRef.doc(invitationId).update({
        'status': 'revoked',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return InvitationResult.ok(message: 'Invitation revoked.');
    } catch (e) {
      return InvitationResult.fail('Failed to revoke: $e');
    }
  }

  /// Streams incoming pending invitations for a recipient.
  Stream<List<InvitationModel>> streamIncomingInvitations(String userId) {
    return _invitationsRef
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => InvitationModel.fromFirestore(d)).toList(),
        );
  }

  /// Streams sent invitations for a publisher.
  Stream<List<InvitationModel>> streamSentInvitations(String publisherId) {
    return _invitationsRef
        .where('publisherId', isEqualTo: publisherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => InvitationModel.fromFirestore(d)).toList(),
        );
  }

  /// Finds and claims an invitation by invite code.
  Future<InvitationModel?> getInvitationByCode(String code) async {
    final snap = await _invitationsRef
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return InvitationModel.fromFirestore(snap.docs.first);
  }
}
