import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized role and permission utilities for POOLING.
class RoleUtils {
  /// Default administrator email for emergency recovery and seeding.
  static const String fallbackAdminEmail = "chaudharideep1106@gmail.com";

  /// Determines whether the given user has administrator privileges.
  /// Checks in priority:
  /// 1. Firebase Auth Custom Claims (`admin: true` or `role: 'admin'`)
  /// 2. Provided Firestore user document data (`role: 'admin'`)
  /// 3. Direct Firestore document lookup if [userData] is null
  /// 4. Seeded recovery admin email
  static Future<bool> isAdmin(User user, [Map<String, dynamic>? userData]) async {
    // 1. Firebase Auth Custom Claims (most secure, evaluated server-side)
    try {
      final tokenResult = await user.getIdTokenResult();
      if (tokenResult.claims?['admin'] == true ||
          tokenResult.claims?['role'] == 'admin') {
        return true;
      }
    } catch (_) {
      // Ignore token fetch issues and fall back to Firestore
    }

    // 2. Check provided Firestore user document data
    if (userData != null && userData['role'] == 'admin') {
      return true;
    }

    // 3. Direct Firestore lookup if not provided
    if (userData == null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data()?['role'] == 'admin') {
          return true;
        }
      } catch (_) {}
    }

    // 4. Fallback check for emergency administration
    if (user.email != null &&
        user.email!.trim().toLowerCase() == fallbackAdminEmail.toLowerCase()) {
      return true;
    }

    return false;
  }
}
