import 'package:flutter_test/flutter_test.dart';
import 'package:riyal1/data/models/ride_model.dart';
import 'package:riyal1/data/models/ride_request_model.dart';

void main() {
  group('RideModel Validation Tests', () {
    test('Rejects empty pickup location', () {
      final err = RideModel.validateInputs(
        from: '',
        to: 'Pune',
        seats: 2,
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        fromLat: 19.0760,
        toLat: 18.5204,
      );
      expect(err, contains('Pickup location is required'));
    });

    test('Rejects identical pickup and destination', () {
      final err = RideModel.validateInputs(
        from: 'Mumbai',
        to: 'Mumbai',
        seats: 2,
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        fromLat: 19.0760,
        toLat: 19.0760,
      );
      expect(err, contains('Pickup and destination must be different'));
    });

    test('Rejects past departure time', () {
      final err = RideModel.validateInputs(
        from: 'Mumbai',
        to: 'Pune',
        seats: 2,
        dateTime: DateTime.now().subtract(const Duration(hours: 1)),
        fromLat: 19.0760,
        toLat: 18.5204,
      );
      expect(err, contains('Departure time must be in the future'));
    });

    test('Rejects invalid seat counts', () {
      final zeroSeatsErr = RideModel.validateInputs(
        from: 'Mumbai',
        to: 'Pune',
        seats: 0,
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        fromLat: 19.0760,
        toLat: 18.5204,
      );
      expect(zeroSeatsErr, contains('Available seats must be at least 1'));

      final tooManySeatsErr = RideModel.validateInputs(
        from: 'Mumbai',
        to: 'Pune',
        seats: 12,
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        fromLat: 19.0760,
        toLat: 18.5204,
      );
      expect(tooManySeatsErr, contains('Maximum seats allowed is 8'));
    });

    test('Accepts valid inputs', () {
      final err = RideModel.validateInputs(
        from: 'Mumbai Central',
        to: 'Pune Station',
        seats: 3,
        dateTime: DateTime.now().add(const Duration(hours: 5)),
        fromLat: 18.9690,
        toLat: 18.5284,
      );
      expect(err, isNull);
    });

    test('RideStatus parses correctly', () {
      expect(RideStatus.fromString('pending'), RideStatus.pending);
      expect(RideStatus.fromString('published'), RideStatus.published);
      expect(RideStatus.fromString('in_progress'), RideStatus.inProgress);
      expect(RideStatus.fromString('completed'), RideStatus.completed);
      expect(RideStatus.fromString('cancelled'), RideStatus.cancelled);
      expect(RideStatus.fromString('unknown_status'), RideStatus.pending);
    });
  });

  group('RideRequestModel Tests', () {
    test('RequestStatus enum parsing', () {
      expect(RequestStatus.fromString('pending'), RequestStatus.pending);
      expect(RequestStatus.fromString('approved'), RequestStatus.approved);
      expect(RequestStatus.fromString('rejected'), RequestStatus.rejected);
      expect(RequestStatus.fromString('cancelled'), RequestStatus.cancelled);
      expect(RequestStatus.fromString('other'), RequestStatus.pending);
    });
  });
}
