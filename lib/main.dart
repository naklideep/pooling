import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/theme/app_theme.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/saved_routes_page.dart';
import 'features/main_shell.dart';
import 'splash_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showLocalNotification(message);
}

void _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'ride_updates_channel',
    'Ride Updates',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? 'You have an update!',
    notificationDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await _initializeNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const PoolingApp());
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showLocalNotification(message);
  });
}

/// Root application widget for Pooling.
class PoolingApp extends StatelessWidget {
  const PoolingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pooling',
      theme: AppTheme.light,
      home: const SplashPage(),
      routes: {
        '/admin': (_) => const AdminDashboardPage(),
        '/main': (_) => const MainShell(),
      },
      onGenerateRoute: (settings) {
        // Named routes that require arguments.
        if (settings.name == '/saved-routes') {
          final args = settings.arguments as Map<String, dynamic>?;
          final uid = args?['userId'] as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => SavedRoutesPage(userId: uid),
          );
        }
        return null;
      },
    );
  }
}