import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

const String notificationServerUrl = "https://ghartak-notifications.onrender.com";

Future<void> sendNotification({
  required String userId,
  required String title,
  required String body,
  Map<String, String>? data,
}) async {
  try {
    // Get the user's FCM token from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final token = userDoc.data()?['fcmToken'];
    print('🔔 FCM Token found: $token'); // ADD THIS

    if (token == null) {
      print('❌ No FCM token for user $userId');
      return;
    }

    final response = await http.post(
      Uri.parse("https://ghartak-notifications.onrender.com/send-notification"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "token": token,
        "title": title,
        "body": body,
        "data": data ?? {},
      }),
    ).timeout(const Duration(seconds: 30)); // ADD TIMEOUT

    print('🔔 Server response: ${response.statusCode} ${response.body}'); // ADD THIS
  } catch (e) {
    print('❌ Notification error: $e'); // ADD THIS
  }
}