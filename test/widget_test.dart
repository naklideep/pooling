import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:riyal1/main.dart';
import 'package:riyal1/pages/login_page.dart';

void main() {
  testWidgets('App loads and shows LoginPage', (WidgetTester tester) async
  {
    // Build our app and trigger a frame.
    await tester.pumpWidget(GharTakApp());

    // Verify that the LoginPage widget is present.
    expect(find.byType(LoginPage), findsOneWidget);

    // Optionally, check for some text or buttons in LoginPage
    expect(find.text('Email'), findsOneWidget); // if LoginPage has a TextField with label 'Email'
    expect(find.text('Password'), findsOneWidget); // if LoginPage has a TextField with label 'Password'
    expect(find.byType(ElevatedButton), findsOneWidget); // login button
  });
}
