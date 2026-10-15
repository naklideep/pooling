import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported vehicle types.
enum VehicleType {
  car,
  twoWheeler;

  static VehicleType fromString(String? val) {
    if (val?.toLowerCase() == 'twowheeler' ||
        val?.toLowerCase() == 'two_wheeler' ||
        val?.toLowerCase() == 'bike') {
      return VehicleType.twoWheeler;
    }
    return VehicleType.car;
  }

  String get displayName =>
      this == VehicleType.car ? 'Car' : 'Two-Wheeler / Bike';
}

/// Vehicle entity owned by a user.
class VehicleModel {
  final String id;
  final String userId;
  final VehicleType type;
  final String makeModel; // e.g., Honda City, Activa 6G
  final String color;
  final String plateNumber;
  final int capacity;
  final bool isDefault;
  final DateTime? createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.makeModel,
    required this.color,
    required this.plateNumber,
    required this.capacity,
    this.isDefault = false,
    this.createdAt,
  });

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: VehicleType.fromString(d['type']),
      makeModel: d['makeModel'] ?? d['model'] ?? '',
      color: d['color'] ?? '',
      plateNumber: d['plateNumber'] ?? d['plate'] ?? '',
      capacity:
          (d['capacity'] as num?)?.toInt() ??
          (d['type'] == 'twoWheeler' ? 1 : 4),
      isDefault: d['isDefault'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type == VehicleType.car ? 'car' : 'twoWheeler',
      'makeModel': makeModel,
      'color': color,
      'plateNumber': plateNumber,
      'capacity': capacity,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
