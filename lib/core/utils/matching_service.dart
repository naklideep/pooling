import 'dart:math';
import '../../data/models/ride_model.dart';
import '../../data/models/commute_schedule_model.dart';

/// Represents the evaluated match score and explanation for a ride.
class RideMatchResult {
  final RideModel ride;
  final double score; // 0.0 to 100.0
  final double pickupDistanceKm;
  final double dropDistanceKm;
  final int timeDiffMinutes;
  final String explanation;

  const RideMatchResult({
    required this.ride,
    required this.score,
    required this.pickupDistanceKm,
    required this.dropDistanceKm,
    required this.timeDiffMinutes,
    required this.explanation,
  });
}

/// Service that computes route compatibility, proximity, time tolerance,
/// and ranks matching rides for subscribers.
class MatchingService {
  /// Calculates great-circle distance between two coordinates in kilometers (Haversine formula).
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Evaluates and ranks candidate rides against a subscriber's search criteria.
  static List<RideMatchResult> findAndRankMatches({
    required List<RideModel> candidateRides,
    required double passengerPickupLat,
    required double passengerPickupLng,
    required double passengerDropLat,
    required double passengerDropLng,
    DateTime? desiredDepartureTime,
    int requiredSeats = 1,
    double maxPickupRadiusKm = 5.0,
    double maxDropRadiusKm = 5.0,
    int maxTimeToleranceMinutes = 120,
    Set<String> subscribedScheduleIds = const {},
  }) {
    final List<RideMatchResult> results = [];

    for (final ride in candidateRides) {
      // 1. Seat check
      if (ride.remainingSeats < requiredSeats) continue;

      // 2. Status check
      if (!ride.canBook) continue;

      // 3. Visibility check
      if (ride.visibility == RideVisibility.inviteOnly) {
        // Invite-only rides are hidden from open search
        continue;
      }
      if (ride.visibility == RideVisibility.subscribersOnly &&
          (ride.scheduleId == null ||
              !subscribedScheduleIds.contains(ride.scheduleId))) {
        // Only visible if passenger is subscribed to this schedule
        continue;
      }

      // 4. Calculate pickup proximity (compare against start or intermediate waypoints)
      double minPickupDist = calculateDistanceKm(
        lat1: passengerPickupLat,
        lon1: passengerPickupLng,
        lat2: ride.fromLat,
        lon2: ride.fromLng,
      );

      String pickupMatchPoint = 'start location';
      for (final wp in ride.waypoints) {
        final dist = calculateDistanceKm(
          lat1: passengerPickupLat,
          lon1: passengerPickupLng,
          lat2: wp.lat,
          lon2: wp.lng,
        );
        if (dist < minPickupDist) {
          minPickupDist = dist;
          pickupMatchPoint = wp.name;
        }
      }

      final maxAllowedDetour = ride.maxDetourKm ?? maxPickupRadiusKm;
      if (minPickupDist > maxAllowedDetour) continue;

      // 5. Calculate destination proximity
      final dropDist = calculateDistanceKm(
        lat1: passengerDropLat,
        lon1: passengerDropLng,
        lat2: ride.toLat,
        lon2: ride.toLng,
      );
      if (dropDist > maxDropRadiusKm) continue;

      // 6. Time tolerance calculation
      int timeDiffMin = 0;
      if (desiredDepartureTime != null && ride.dateTime != null) {
        timeDiffMin = ride.dateTime!
            .difference(desiredDepartureTime)
            .inMinutes
            .abs();
        if (timeDiffMin > maxTimeToleranceMinutes) continue;
      }

      // 7. Calculate overall weighted score (0 to 100)
      // Proximity score (0-50 pts): closer pickup/drop gives more points
      final proximityScore = max(
        0.0,
        50.0 - (minPickupDist * 4.0) - (dropDist * 3.0),
      );

      // Time score (0-30 pts): closer departure time gives more points
      final timeScore = max(0.0, 30.0 - (timeDiffMin * 0.25));

      // Seat availability bonus (0-10 pts)
      final seatBonus = min(10.0, ride.remainingSeats * 2.5);

      // Route waypoint match bonus (0-10 pts)
      final waypointBonus = pickupMatchPoint != 'start location' ? 10.0 : 0.0;

      final totalScore = (proximityScore + timeScore + seatBonus + waypointBonus)
          .clamp(0.0, 100.0);

      // 8. Generate friendly explanation
      final reasons = <String>[];
      if (minPickupDist < 1.0) {
        reasons.add(
          'Pickup within ${(minPickupDist * 1000).round()}m of $pickupMatchPoint',
        );
      } else {
        reasons.add(
          'Pickup ${minPickupDist.toStringAsFixed(1)}km from $pickupMatchPoint',
        );
      }
      if (timeDiffMin <= 15) {
        reasons.add('Departs around your desired time');
      } else {
        reasons.add('Departs within ${timeDiffMin}m');
      }
      reasons.add('${ride.remainingSeats} seat(s) available');

      results.add(
        RideMatchResult(
          ride: ride,
          score: totalScore,
          pickupDistanceKm: minPickupDist,
          dropDistanceKm: dropDist,
          timeDiffMinutes: timeDiffMin,
          explanation: reasons.join(' • '),
        ),
      );
    }

    // Sort by highest match score first
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }
}
