import 'package:cloud_firestore/cloud_firestore.dart';

/// Invitation status lifecycle enum.
enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  revoked;

  static InvitationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return InvitationStatus.accepted;
      case 'declined':
        return InvitationStatus.declined;
      case 'expired':
        return InvitationStatus.expired;
      case 'revoked':
        return InvitationStatus.revoked;
      case 'pending':
      default:
        return InvitationStatus.pending;
    }
  }

  String toDbString() => name;

  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.declined:
        return 'Declined';
      case InvitationStatus.expired:
        return 'Expired';
      case InvitationStatus.revoked:
        return 'Revoked';
    }
  }
}

/// Scope of the invitation: one specific ride occurrence, or the recurring commute schedule.
enum InvitationScope {
  occurrence,
  schedule;

  static InvitationScope fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'schedule':
        return InvitationScope.schedule;
      case 'occurrence':
      default:
        return InvitationScope.occurrence;
    }
  }

  String toDbString() => name;
}

/// Domain model for direct invitations sent by publishers to riders.
class InvitationModel {
  final String id;
  final String publisherId;
  final String publisherName;
  final String? publisherPhoto;
  final String? recipientId;
  final String? recipientEmail;
  final String? recipientName;
  final String? recipientPhone;
  final String? rideId;
  final String? scheduleId;
  final String from;
  final String to;
  final DateTime? rideDateTime;
  final InvitationScope scope;
  final String inviteCode;
  final InvitationStatus status;
  final int seatsOffered;
  final DateTime? expiresAt;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  const InvitationModel({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    this.publisherPhoto,
    this.recipientId,
    this.recipientEmail,
    this.recipientName,
    this.recipientPhone,
    this.rideId,
    this.scheduleId,
    required this.from,
    required this.to,
    this.rideDateTime,
    this.scope = InvitationScope.occurrence,
    required this.inviteCode,
    this.status = InvitationStatus.pending,
    this.seatsOffered = 1,
    this.expiresAt,
    this.respondedAt,
    this.createdAt,
  });

  bool get isPending => status == InvitationStatus.pending;
  bool get isExpired {
    if (status == InvitationStatus.expired) return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return InvitationModel(
      id: doc.id,
      publisherId: d['publisherId'] ?? '',
      publisherName: d['publisherName'] ?? 'Publisher',
      publisherPhoto: d['publisherPhoto'],
      recipientId: d['recipientId'],
      recipientEmail: d['recipientEmail'],
      recipientName: d['recipientName'],
      recipientPhone: d['recipientPhone'],
      rideId: d['rideId'],
      scheduleId: d['scheduleId'],
      from: d['from'] ?? '',
      to: d['to'] ?? '',
      rideDateTime: parseDate(d['rideDateTime'] ?? d['dateTime']),
      scope: InvitationScope.fromString(d['scope']),
      inviteCode: d['inviteCode'] ?? '',
      status: InvitationStatus.fromString(d['status']),
      seatsOffered: (d['seatsOffered'] as num?)?.toInt() ?? 1,
      expiresAt: parseDate(d['expiresAt']),
      respondedAt: parseDate(d['respondedAt']),
      createdAt: parseDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publisherId': publisherId,
      'publisherName': publisherName,
      if (publisherPhoto != null) 'publisherPhoto': publisherPhoto,
      if (recipientId != null) 'recipientId': recipientId,
      if (recipientEmail != null) 'recipientEmail': recipientEmail,
      if (recipientName != null) 'recipientName': recipientName,
      if (recipientPhone != null) 'recipientPhone': recipientPhone,
      if (rideId != null) 'rideId': rideId,
      if (scheduleId != null) 'scheduleId': scheduleId,
      'from': from,
      'to': to,
      if (rideDateTime != null) 'rideDateTime': Timestamp.fromDate(rideDateTime!),
      'scope': scope.toDbString(),
      'inviteCode': inviteCode,
      'status': status.toDbString(),
      'seatsOffered': seatsOffered,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
