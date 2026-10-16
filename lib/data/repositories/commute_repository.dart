import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/commute_schedule_model.dart';
import '../models/ride_model.dart';

/// Result wrapper for commute operations.
class CommuteResult {
  final bool success;
  final String? message;
  final String? scheduleId;

  const CommuteResult._({required this.success, this.message, this.scheduleId});

  factory CommuteResult.ok({String? message, String? scheduleId}) =>
      CommuteResult._(success: true, message: message, scheduleId: scheduleId);

  factory CommuteResult.fail(String error) =>
      CommuteResult._(success: false, message: error);
}

/// Repository for managing recurring commute schedules and their ride occurrences.
class CommuteRepository {
  final FirebaseFirestore? _customFirestore;

  CommuteRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference get _schedulesRef =>
      _firestore.collection('commuteSchedules');
  CollectionReference get _ridesRef => _firestore.collection('rides');

  /// Creates a recurring commute schedule and generates upcoming occurrences.
  Future<CommuteResult> createSchedule(CommuteScheduleModel schedule) async {
    try {
      final docRef = _schedulesRef.doc();
      final scheduleId = docRef.id;

      final data = schedule.toMap();
      await docRef.set(data);

      // Generate occurrences for the next 14 days
      await generateOccurrences(
        scheduleId: scheduleId,
        scheduleData: schedule,
        daysAhead: 14,
      );

      return CommuteResult.ok(
        scheduleId: scheduleId,
        message: 'Recurring commute published successfully!',
      );
    } catch (e) {
      return CommuteResult.fail('Failed to publish commute schedule: $e');
    }
  }

  /// Generates individual ride occurrences in `rides` collection.
  ///
  /// Uses deterministic doc IDs (`${scheduleId}_${occurrenceDate}`) so
  /// it is completely idempotent and will never overwrite existing bookings.
  Future<int> generateOccurrences({
    required String scheduleId,
    required CommuteScheduleModel scheduleData,
    int daysAhead = 14,
  }) async {
    int createdCount = 0;
    final now = DateTime.now();

    // Parse departure time ("HH:mm")
    final timeParts = scheduleData.departureTime.split(':');
    final depHour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 9 : 9;
    final depMinute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

    final batch = _firestore.batch();
    bool hasBatchedWrites = false;

    for (int i = 0; i < daysAhead; i++) {
      final targetDate = now.add(Duration(days: i));
      final weekday = targetDate.weekday; // 1 = Mon, 7 = Sun

      // Check if this weekday is part of the schedule
      if (!scheduleData.daysOfWeek.contains(weekday)) continue;

      // Construct departure datetime for that date
      final occurrenceDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        depHour,
        depMinute,
      );

      // Skip occurrences in the past
      if (occurrenceDateTime.isBefore(now)) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final occurrenceDocId = '${scheduleId}_$dateStr';

      final occurrenceDoc = await _ridesRef.doc(occurrenceDocId).get();
      if (occurrenceDoc.exists) {
        // Occurrence already generated; do not mutate existing bookings
        continue;
      }

      // Generate random 4-digit security PIN for this occurrence
      final rideCode = (1000 + Random.secure().nextInt(9000)).toString();

      final occurrenceData = <String, dynamic>{
        'scheduleId': scheduleId,
        'occurrenceDate': dateStr,
        'riderId': scheduleData.publisherId,
        'postedByName': scheduleData.publisherName,
        if (scheduleData.publisherPhoto != null)
          'publisherPhoto': scheduleData.publisherPhoto,
        'from': scheduleData.from,
        'to': scheduleData.to,
        'from_lat': scheduleData.fromLat,
        'from_lng': scheduleData.fromLng,
        'to_lat': scheduleData.toLat,
        'to_lng': scheduleData.toLng,
        'waypoints': scheduleData.waypoints.map((w) => w.toMap()).toList(),
        'seats': scheduleData.seats,
        'remainingSeats': scheduleData.seats,
        'rideType': scheduleData.rideType,
        'allowMultiple': true,
        if (scheduleData.distanceKm != null)
          'distance_km': scheduleData.distanceKm,
        if (scheduleData.estimatedDurationMin != null)
          'duration_min': scheduleData.estimatedDurationMin,
        'estimatedCost': scheduleData.estimatedCostPerSeat,
        'dateTime': Timestamp.fromDate(occurrenceDateTime),
        'status': 'published',
        'visibility': scheduleData.visibility.toDbString(),
        'acceptedByList': <String>[],
        'rideCode': rideCode,
        if (scheduleData.notes != null) 'notes': scheduleData.notes,
        'maxDetourKm': scheduleData.maxDetourKm,
        'timestamp': FieldValue.serverTimestamp(),
      };

      batch.set(_ridesRef.doc(occurrenceDocId), occurrenceData);
      hasBatchedWrites = true;
      createdCount++;
    }

    if (hasBatchedWrites) {
      await batch.commit();
    }

    return createdCount;
  }

  /// Pauses a recurring commute schedule.
  Future<CommuteResult> pauseSchedule(String scheduleId) async {
    try {
      await _schedulesRef.doc(scheduleId).update({
        'status': CommuteStatus.paused.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return CommuteResult.ok(message: 'Commute schedule paused.');
    } catch (e) {
      return CommuteResult.fail('Failed to pause schedule: $e');
    }
  }

  /// Resumes a recurring commute schedule and generates upcoming rides.
  Future<CommuteResult> resumeSchedule(String scheduleId) async {
    try {
      final doc = await _schedulesRef.doc(scheduleId).get();
      if (!doc.exists) return CommuteResult.fail('Schedule not found.');

      final schedule = CommuteScheduleModel.fromFirestore(doc);
      await _schedulesRef.doc(scheduleId).update({
        'status': CommuteStatus.active.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await generateOccurrences(
        scheduleId: scheduleId,
        scheduleData: schedule,
        daysAhead: 14,
      );

      return CommuteResult.ok(message: 'Commute schedule resumed.');
    } catch (e) {
      return CommuteResult.fail('Failed to resume schedule: $e');
    }
  }

  /// Ends a recurring commute schedule permanently.
  Future<CommuteResult> endSchedule(String scheduleId) async {
    try {
      await _schedulesRef.doc(scheduleId).update({
        'status': CommuteStatus.ended.toDbString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return CommuteResult.ok(message: 'Commute schedule ended.');
    } catch (e) {
      return CommuteResult.fail('Failed to end schedule: $e');
    }
  }

  /// Stream of schedules published by a specific user.
  Stream<List<CommuteScheduleModel>> streamPublisherSchedules(
    String publisherId,
  ) {
    return _schedulesRef
        .where('publisherId', isEqualTo: publisherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommuteScheduleModel.fromFirestore(d))
              .toList(),
        );
  }

  /// Stream of active discoverable recurring commute schedules.
  Stream<List<CommuteScheduleModel>> streamDiscoverableSchedules() {
    return _schedulesRef
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommuteScheduleModel.fromFirestore(d))
              .toList(),
        );
  }

  /// Stream of individual ride occurrences for a given schedule.
  Stream<List<RideModel>> streamOccurrencesForSchedule(String scheduleId) {
    return _ridesRef
        .where('scheduleId', isEqualTo: scheduleId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RideModel.fromFirestore(d)).toList(),
        );
  }

  /// Fetch a single schedule by ID.
  Future<CommuteScheduleModel?> getSchedule(String scheduleId) async {
    final doc = await _schedulesRef.doc(scheduleId).get();
    if (!doc.exists) return null;
    return CommuteScheduleModel.fromFirestore(doc);
  }
}
