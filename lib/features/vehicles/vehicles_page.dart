import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vehicle_model.dart';

/// Vehicle management screen where users can list, add, and delete their vehicles.
class VehiclesPage extends StatefulWidget {
  final String userId;
  const VehiclesPage({super.key, required this.userId});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  CollectionReference get _vehiclesRef =>
      FirebaseFirestore.instance.collection('vehicles');

  Future<void> _openAddVehicleDialog([VehicleModel? existing]) async {
    final formKey = GlobalKey<FormState>();
    final modelCtrl = TextEditingController(text: existing?.makeModel ?? '');
    final colorCtrl = TextEditingController(text: existing?.color ?? '');
    final plateCtrl = TextEditingController(text: existing?.plateNumber ?? '');
    int capacity = existing?.capacity ?? 4;
    VehicleType type = existing?.type ?? VehicleType.car;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        existing == null ? 'Add Vehicle' : 'Edit Vehicle',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Vehicle Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: _TypeChip(
                              label: 'Car',
                              icon: Icons.directions_car_rounded,
                              selected: type == VehicleType.car,
                              onTap: () {
                                setSheetState(() {
                                  type = VehicleType.car;
                                  if (capacity < 2) capacity = 4;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeChip(
                              label: 'Two-Wheeler',
                              icon: Icons.two_wheeler_rounded,
                              selected: type == VehicleType.twoWheeler,
                              onTap: () {
                                setSheetState(() {
                                  type = VehicleType.twoWheeler;
                                  capacity = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: modelCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Make & Model',
                          hintText: 'e.g. Honda City / Activa 6G',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter make & model'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: colorCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Color',
                                hintText: 'e.g. White, Silver',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter color'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: plateCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Plate Number',
                                hintText: 'e.g. MH 02 AB 1234',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter plate'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Capacity Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Passenger Capacity',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: capacity > 1
                                    ? () => setSheetState(() => capacity--)
                                    : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  '$capacity',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed:
                                    capacity < (type == VehicleType.car ? 7 : 2)
                                    ? () => setSheetState(() => capacity++)
                                    : null,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.yellow,
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isSaving = true);

                                try {
                                  final vehicle = VehicleModel(
                                    id: existing?.id ?? '',
                                    userId: widget.userId,
                                    type: type,
                                    makeModel: modelCtrl.text.trim(),
                                    color: colorCtrl.text.trim(),
                                    plateNumber: plateCtrl.text.trim(),
                                    capacity: capacity,
                                  );

                                  if (existing == null) {
                                    await _vehiclesRef.add(vehicle.toMap());
                                  } else {
                                    await _vehiclesRef
                                        .doc(existing.id)
                                        .update(vehicle.toMap());
                                  }

                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                } catch (e) {
                                  setSheetState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to save vehicle: $e',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: Text(
                          isSaving ? 'Saving…' : 'Save Vehicle',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: const Text('Are you sure you want to remove this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _vehiclesRef.doc(vehicleId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Vehicles'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.navy,
        onPressed: () => _openAddVehicleDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Vehicle',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _vehiclesRef
            .where('userId', isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_outlined,
                        size: 44,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No vehicles added yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add your car or two-wheeler to offer rides to commuters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = VehicleModel.fromFirestore(docs[index]);
              final isCar = vehicle.type == VehicleType.car;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCar
                            ? Icons.directions_car_rounded
                            : Icons.two_wheeler_rounded,
                        color: AppColors.navy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.makeModel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.color} • ${vehicle.plateNumber}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.capacity} passenger seats',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => _openAddVehicleDialog(vehicle),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () => _deleteVehicle(vehicle.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
