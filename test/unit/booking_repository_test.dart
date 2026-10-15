import 'package:flutter_test/flutter_test.dart';
import 'package:riyal1/data/repositories/booking_repository.dart';

void main() {
  group('BookingRepository Unit Logic Tests', () {
    test('Rejects zero seats booking request', () async {
      final repo = BookingRepository();
      final res = await repo.requestSeat(
        rideId: 'fake_ride',
        passengerId: 'user_1',
        passengerName: 'Passenger',
        requestedSeats: 0,
      );
      expect(res.success, isFalse);
      expect(res.message, contains('Must request at least 1 seat'));
    });

    test('Rejects negative seats booking request', () async {
      final repo = BookingRepository();
      final res = await repo.requestSeat(
        rideId: 'fake_ride',
        passengerId: 'user_1',
        passengerName: 'Passenger',
        requestedSeats: -2,
      );
      expect(res.success, isFalse);
      expect(res.message, contains('Must request at least 1 seat'));
    });

    test('BookingResult factory constructors work correctly', () {
      final ok = BookingResult.ok(message: 'Success', requestId: 'req_123');
      expect(ok.success, isTrue);
      expect(ok.message, 'Success');
      expect(ok.requestId, 'req_123');

      final fail = BookingResult.fail('Failed due to error');
      expect(fail.success, isFalse);
      expect(fail.message, 'Failed due to error');
      expect(fail.requestId, isNull);
    });
  });
}
