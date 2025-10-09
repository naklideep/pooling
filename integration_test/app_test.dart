import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riyal1/main.dart' as app; // replace with your main.dart import path

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RideBuddy Full Flow Test', () {
    testWidgets('Login -> Post Ride', (WidgetTester tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // 1️⃣ Login Page
      const testEmail = 'con717382@gmail.com'; // replace with your test account
      const testPassword = 'Deep1212@';

      await tester.enterText(find.byKey(Key('emailLoginField')), testEmail);
      await tester.enterText(find.byKey(Key('passwordLoginField')), testPassword);
      await tester.tap(find.byKey(Key('loginButton')));

      // Wait for Firebase authentication to complete
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // ✅ Verify Dashboard loaded
      expect(find.text('Dashboard'), findsOneWidget);

      // 2️⃣ Switch to "Post Ride" tab
      await tester.tap(find.text('Post Ride'));
      await tester.pumpAndSettle();

      // 3️⃣ Fill Post Ride form
      await tester.enterText(find.byKey(Key('fromField')), 'Mumbai');
      await tester.enterText(find.byKey(Key('toField')), 'Pune');
      await tester.enterText(find.byKey(Key('seatsField')), '2');
      await tester.enterText(find.byKey(Key('dateField')), '2025-10-10');
      await tester.enterText(find.byKey(Key('timeField')), '10:00 AM');

      // Optional: small delay before submission
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 4️⃣ Submit Post Ride
      await tester.tap(find.byKey(Key('postRideButton')));
      await tester.pumpAndSettle();

      // Optional: wait for Firestore write confirmation
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // 5️⃣ Verify ride posted message
      expect(find.textContaining('Ride posted successfully'), findsOneWidget);
    });
  });
}
