import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riyal1/main.dart' as app;
import 'package:riyal1/pages/post_ride.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RideBuddy Full Flow Test', () {
    // Use a pre-verified Firebase test account
    const testEmail = 'con717382@gmail.com';
    const testPassword = 'Deep1212@';

    testWidgets('Login -> Post Ride', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // LOGIN
      final emailField = find.byKey(Key('emailLoginField'));
      final passwordField = find.byKey(Key('passwordLoginField'));
      final loginButton = find.byKey(Key('loginButton'));

      await tester.enterText(emailField, testEmail);
      await tester.enterText(passwordField, testPassword);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Check that Dashboard is displayed
      expect(find.text('Dashboard'), findsOneWidget);

      // POST RIDE
      // Navigate to Post Ride tab (assume first tab)
      final postRideTab = find.text('Post Ride');
      await tester.tap(postRideTab);
      await tester.pumpAndSettle();

      final fromField = find.byKey(Key('fromField'));
      final toField = find.byKey(Key('toField'));
      final seatsField = find.byKey(Key('seatsField'));
      final dateField = find.byKey(Key('dateField'));
      final timeField = find.byKey(Key('timeField'));
      final postRideButton = find.byKey(Key('postRideButton'));

      await tester.enterText(fromField, 'Mumbai');
      await tester.enterText(toField, 'Pune');
      await tester.enterText(seatsField, '2');
      await tester.enterText(dateField, '2025-10-10');
      await tester.enterText(timeField, '10:00 AM');

      await tester.tap(postRideButton);
      await tester.pumpAndSettle();

      // Verify ride posted success snackbar
      expect(find.textContaining('Ride posted successfully'), findsOneWidget);
    });
  });
}
