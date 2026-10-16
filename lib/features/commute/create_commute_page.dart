import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../data/models/commute_schedule_model.dart';
import '../../data/repositories/commute_repository.dart';
import '../../pages/enhanced_map_picker.dart';

/// Screen allowing publishers to create recurring commute schedules with waypoints.
class CreateCommutePage extends StatefulWidget {
  const CreateCommutePage({super.key});

  @override
  State<CreateCommutePage> createState() => _CreateCommutePageState();
}

class _CreateCommutePageState extends State<CreateCommutePage> {
  final _formKey = GlobalKey<FormState>();
  final _commuteRepo = CommuteRepository();

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '3');
  final _costCtrl = TextEditingController(text: '70');
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double? _fromLat, _fromLng;
  double? _toLat, _toLng;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final List<int> _selectedDays = [1, 2, 3, 4, 5]; // Mon - Fri default
  final List<RouteWaypoint> _waypoints = [];
  String _rideType = 'Car';
  RideVisibility _visibility = RideVisibility.publicVisibility;
  double _maxDetourKm = 3.0;

  bool _isSaving = false;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _seatsCtrl.dispose();
    _costCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addWaypointDialog() {
    final wpNameCtrl = TextEditingController();
    double? wpLat;
    double? wpLng;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Stop / Waypoint'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wpNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Stop Name (e.g. Wakad Bridge)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  wpLat != null
                      ? 'Location Selected ✓'
                      : 'Pick Stop on Map',
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnhancedMapPicker(
                        title: 'Select Intermediate Stop',
                      ),
                    ),
                  );
                  if (result != null && result is Map) {
                    setDialogState(() {
                      wpLat = (result['lat'] as num).toDouble();
                      wpLng = (result['lng'] as num).toDouble();
                      if (wpNameCtrl.text.isEmpty && result['address'] != null) {
                        wpNameCtrl.text = result['address'].toString();
                      }
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = wpNameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  _waypoints.add(
                    RouteWaypoint(
                      name: name,
                      lat: wpLat ?? _fromLat ?? 0.0,
                      lng: wpLng ?? _fromLng ?? 0.0,
                    ),
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Stop'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCommute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromLat == null || _toLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select valid map locations for pickup and destination.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day for your recurring commute.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String userName = user.displayName ?? 'Publisher';
      String? userPhoto = user.photoURL;

      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (uDoc.exists) {
        final d = uDoc.data();
        if (d?['name'] != null) userName = d!['name'];
        if (d?['photoUrl'] != null) userPhoto = d!['photoUrl'];
      }

      final depHourStr = _selectedTime.hour.toString().padLeft(2, '0');
      final depMinStr = _selectedTime.minute.toString().padLeft(2, '0');
      final timeStr = '$depHourStr:$depMinStr';

      final schedule = CommuteScheduleModel(
        id: '',
        publisherId: user.uid,
        publisherName: userName,
        publisherPhoto: userPhoto,
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
        fromLat: _fromLat!,
        fromLng: _fromLng!,
        toLat: _toLat!,
        toLng: _toLng!,
        waypoints: _waypoints,
        departureTime: timeStr,
        daysOfWeek: _selectedDays,
        seats: int.tryParse(_seatsCtrl.text.trim()) ?? 3,
        estimatedCostPerSeat: int.tryParse(_costCtrl.text.trim()) ?? 70,
        vehicleModel: _vehicleModelCtrl.text.trim().isNotEmpty
            ? _vehicleModelCtrl.text.trim()
            : null,
        vehicleNumber: _vehicleNumberCtrl.text.trim().isNotEmpty
            ? _vehicleNumberCtrl.text.trim()
            : null,
        rideType: _rideType,
        visibility: _visibility,
        maxDetourKm: _maxDetourKm,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        startDate: DateTime.now(),
      );

      final res = await _commuteRepo.createSchedule(schedule);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Commute published successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to publish commute.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PoolingHeader(subtitle: 'Publish Recurring Commute'),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader('Route & Waypoints', Icons.route_rounded),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    title: 'Pickup Location',
                    controller: _fromCtrl,
                    icon: Icons.trip_origin_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    hasCoords: _fromLat != null,
                    onPickMap: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnhancedMapPicker(
                            title: 'Select Pickup Location',
                          ),
                        ),
                      );
                      if (res != null && res is Map) {
                        setState(() {
                          _fromLat = (res['lat'] as num).toDouble();
                          _fromLng = (res['lng'] as num).toDouble();
                          _fromCtrl.text = res['address'] ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildLocationCard(
                    title: 'Destination',
                    controller: _toCtrl,
                    icon: Icons.location_on_rounded,
                    iconColor: Colors.redAccent,
                    hasCoords: _toLat != null,
                    onPickMap: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnhancedMapPicker(
                            title: 'Select Destination',
                          ),
                        ),
                      );
                      if (res != null && res is Map) {
                        setState(() {
                          _toLat = (res['lat'] as num).toDouble();
                          _toLng = (res['lng'] as num).toDouble();
                          _toCtrl.text = res['address'] ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Waypoints list
                  if (_waypoints.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._waypoints.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final wp = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.navy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stop ${idx + 1}: ${wp.name}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                              onPressed: () => setState(() => _waypoints.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  TextButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add Intermediate Stop / Waypoint'),
                    onPressed: _addWaypointDialog,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader('Schedule & Timing', Icons.schedule_rounded),
                  const SizedBox(height: 12),

                  // Departure time picker card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily Departure Time',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.access_time_rounded, size: 18),
                          label: const Text('Change'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (picked != null) {
                              setState(() => _selectedTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Recurring Days Selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recurring Commute Days',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDays.clear();
                                  _selectedDays.addAll([1, 2, 3, 4, 5]);
                                });
                              },
                              child: const Text('Weekdays'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final dayNum = i + 1; // 1=Mon, 7=Sun
                            final isSel = _selectedDays.contains(dayNum);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSel) {
                                    if (_selectedDays.length > 1) {
                                      _selectedDays.remove(dayNum);
                                    }
                                  } else {
                                    _selectedDays.add(dayNum);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.navy : AppColors.surfaceDim,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? AppColors.navy : AppColors.border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  dayLabels[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader('Seats, Vehicle & Visibility', Icons.directions_car_rounded),
                  const SizedBox(height: 12),

                  // Seats and Cost row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _seatsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Available Seats',
                            prefixIcon: const Icon(Icons.event_seat_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1 || n > 8) return '1 - 8 seats';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cost / Seat (₹)',
                            prefixIcon: const Icon(Icons.currency_rupee),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) return 'Valid cost';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Visibility dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<RideVisibility>(
                        value: _visibility,
                        isExpanded: true,
                        items: RideVisibility.values.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Row(
                              children: [
                                Icon(
                                  v == RideVisibility.publicVisibility
                                      ? Icons.public_rounded
                                      : v == RideVisibility.subscribersOnly
                                          ? Icons.people_outline_rounded
                                          : Icons.lock_outline_rounded,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                                const SizedBox(width: 10),
                                Text(v.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _visibility = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Max detour slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Max Allowed Detour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              '${_maxDetourKm.toStringAsFixed(1)} km',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
                            ),
                          ],
                        ),
                        Slider(
                          value: _maxDetourKm,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          activeColor: AppColors.navy,
                          onChanged: (val) => setState(() => _maxDetourKm = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Vehicle Details (optional)
                  TextFormField(
                    controller: _vehicleModelCtrl,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Model (optional)',
                      hintText: 'e.g. Honda City / Activa 6G',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes (optional)
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes & Preferences (optional)',
                      hintText: 'e.g. AC will be on, no boot space for large bags',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitCommute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Publish Commute & Occurrences',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navy),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
      ],
    );
  }

  Widget _buildLocationCard({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required bool hasCoords,
    required VoidCallback onPickMap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 16),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
              InkWell(
                onTap: onPickMap,
                child: Text(
                  hasCoords ? 'Change on map' : 'Pick on map',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              hintText: 'Enter location address…',
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
