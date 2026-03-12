import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'enhanced_map_picker.dart';

class T {
  static const bg        = Color(0xFFE8EAF0);
  static const surface   = Color(0xFF1C2340);
  static const card      = Color(0xFFFFFFFF);
  static const navyCard  = Color(0xFF1E2D5A);
  static const yellow    = Color(0xFFFFCC00);
  static const yellowDim = Color(0x33FFCC00);
  static const txtDark   = Color(0xFF1A1A2E);
  static const txtMed    = Color(0xFF555577);
  static const txtLight  = Color(0xFF9999BB);
  static const txtWhite  = Color(0xFFFFFFFF);
  static const green     = Color(0xFFFFCC00);
  static const red       = Color(0xFFFF3D3D);
  static const border    = Color(0xFFDDDDE8);
  static const shadow    = Color(0x14000000);
}

class SavedRoute {
  final String id;
  final String fromAddress;
  final String toAddress;
  final LatLng? fromCoords;
  final LatLng? toCoords;
  final DateTime savedAt;
  final int usageCount;
  final bool isFavourite;
  final String? nickname;
  final String? mode;
  final String? time;

  SavedRoute({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    this.fromCoords,
    this.toCoords,
    required this.savedAt,
    this.usageCount = 0,
    this.isFavourite = false,
    this.nickname,
    this.mode,
    this.time,
  });

  bool get hasCoords => fromCoords != null && toCoords != null;

  factory SavedRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    LatLng? fromCoords;
    LatLng? toCoords;
    if (d['from_lat'] != null && d['from_lng'] != null) {
      fromCoords = LatLng((d['from_lat'] as num).toDouble(), (d['from_lng'] as num).toDouble());
    }
    if (d['to_lat'] != null && d['to_lng'] != null) {
      toCoords = LatLng((d['to_lat'] as num).toDouble(), (d['to_lng'] as num).toDouble());
    }
    final savedAt = d['savedAt'] != null
        ? (d['savedAt'] as Timestamp).toDate()
        : d['createdAt'] != null
        ? (d['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    return SavedRoute(
      id: doc.id,
      fromAddress: d['fromAddress'] ?? d['from'] ?? '',
      toAddress: d['toAddress'] ?? d['to'] ?? '',
      fromCoords: fromCoords,
      toCoords: toCoords,
      savedAt: savedAt,
      usageCount: d['usageCount'] ?? 0,
      isFavourite: d['isFavourite'] ?? false,
      nickname: d['nickname'],
      mode: d['mode'],
      time: d['time'],
    );
  }

  // ✅ Clean toMap() — no floating code here
  Map<String, dynamic> toMap() => {
    'fromAddress': fromAddress,
    'toAddress': toAddress,
    if (fromCoords != null) 'from_lat': fromCoords!.latitude,
    if (fromCoords != null) 'from_lng': fromCoords!.longitude,
    if (toCoords != null) 'to_lat': toCoords!.latitude,
    if (toCoords != null) 'to_lng': toCoords!.longitude,
    'usageCount': usageCount,
    'isFavourite': isFavourite,
    if (nickname != null) 'nickname': nickname,
    if (mode != null) 'mode': mode,
    if (time != null) 'time': time,
    'savedAt': FieldValue.serverTimestamp(),
  };
}

// ─────────────────────────────────────────────
// PostRidePage
// ─────────────────────────────────────────────
class PostRidePage extends StatefulWidget {
  final SavedRoute? prefilledRoute;
  const PostRidePage({super.key, this.prefilledRoute});

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _fromCtrl      = TextEditingController();
  final _toCtrl        = TextEditingController();
  final _seatsCtrl     = TextEditingController();
  final _mapController = MapController();

  LatLng?   _fromCoords, _toCoords;
  DateTime? _selectedDateTime;

  bool    _isLoading        = false;
  bool    _loadingMap       = true;
  bool    _calculatingRoute = false;
  bool    _savingRoute      = false;
  String? _selectedRideType = "Car";
  bool    _allowMultiple    = true;

  double?      _distanceKm, _durationMin;
  List<LatLng> _routePoints  = [];
  List<SavedRoute> _savedRoutes = [];
  bool    _loadingSavedRoutes = true;

  late AnimationController _anim;
  late Animation<double>   _fade;

  CollectionReference get _routesRef {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('saved_routes');
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
    if (widget.prefilledRoute != null) {
      _applyPrefilledRoute(widget.prefilledRoute!);
    } else {
      _autoDetectCurrentLocation();
    }
    _loadSavedRoutes();
  }

  @override
  void dispose() {
    _fromCtrl.dispose(); _toCtrl.dispose(); _seatsCtrl.dispose(); _anim.dispose();
    super.dispose();
  }

  void _applyPrefilledRoute(SavedRoute r) {
    _fromCtrl.text = r.fromAddress;
    _toCtrl.text   = r.toAddress;
    _fromCoords    = r.fromCoords;
    _toCoords      = r.toCoords;
    setState(() => _loadingMap = false);
    if (r.hasCoords) WidgetsBinding.instance.addPostFrameCallback((_) => _calculateRouteInfo());
  }

  Future<void> _loadSavedRoutes() async {
    try {
      final snap = await _routesRef.orderBy('usageCount', descending: true).get();
      setState(() {
        _savedRoutes = snap.docs.map((d) => SavedRoute.fromFirestore(d)).where((r) => r.hasCoords).toList();
        _loadingSavedRoutes = false;
      });
    } catch (e) { setState(() => _loadingSavedRoutes = false); }
  }

  Future<void> _saveCurrentRoute() async {
    if (_fromCoords == null || _toCoords == null) { _showError("Select both locations before saving"); return; }
    final isDup = _savedRoutes.any((r) =>
    r.fromCoords != null && r.toCoords != null &&
        (r.fromCoords!.latitude  - _fromCoords!.latitude).abs()  < 0.001 &&
        (r.fromCoords!.longitude - _fromCoords!.longitude).abs() < 0.001 &&
        (r.toCoords!.latitude    - _toCoords!.latitude).abs()    < 0.001 &&
        (r.toCoords!.longitude   - _toCoords!.longitude).abs()   < 0.001);
    if (isDup) { _showError("This route is already saved!"); return; }
    setState(() => _savingRoute = true);
    try {
      final route = SavedRoute(id: '', fromAddress: _fromCtrl.text.trim(), toAddress: _toCtrl.text.trim(),
          fromCoords: _fromCoords, toCoords: _toCoords, savedAt: DateTime.now());
      final doc = await _routesRef.add(route.toMap());
      setState(() => _savedRoutes.insert(0, SavedRoute(id: doc.id, fromAddress: route.fromAddress,
          toAddress: route.toAddress, fromCoords: route.fromCoords, toCoords: route.toCoords, savedAt: route.savedAt)));
      _showSuccess("Route saved!");
    } catch (e) { _showError("Failed to save route: ${e.toString()}");
    } finally { setState(() => _savingRoute = false); }
  }

  Future<void> _deleteSavedRoute(SavedRoute route) async {
    try {
      await _routesRef.doc(route.id).delete();
      setState(() => _savedRoutes.removeWhere((r) => r.id == route.id));
      _showSuccess("Route removed");
    } catch (e) { _showError("Failed to delete: ${e.toString()}"); }
  }

  void _applySavedRoute(SavedRoute route) {
    if (!route.hasCoords) return;
    setState(() { _fromCtrl.text = route.fromAddress; _toCtrl.text = route.toAddress;
    _fromCoords = route.fromCoords; _toCoords = route.toCoords; });
    _calculateRouteInfo();
    _routesRef.doc(route.id).update({'usageCount': FieldValue.increment(1), 'lastUsed': FieldValue.serverTimestamp()});
    _showSuccess("Route loaded!");
  }

  Future<void> _autoDetectCurrentLocation() async {
    setState(() => _loadingMap = true);
    try {
      bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) { _showError("Location services are disabled."); setState(() => _loadingMap = false); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { _showError("Location permission denied."); setState(() => _loadingMap = false); return; }
      }
      if (perm == LocationPermission.deniedForever) { _showError("Location permission permanently denied."); setState(() => _loadingMap = false); return; }
      final pos   = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p    = marks.first;
        final addr = [p.street, p.locality, p.administrativeArea, p.country].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() { _fromCtrl.text = addr.isNotEmpty ? addr : "Current Location"; _fromCoords = LatLng(pos.latitude, pos.longitude); _loadingMap = false; });
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _mapController.move(LatLng(pos.latitude, pos.longitude), 14); });
        _showSuccess("Location detected!");
      }
    } catch (e) { _showError("Failed to detect location."); setState(() => _loadingMap = false); }
  }

  Future<void> _calculateRouteInfo() async {
    if (_fromCoords == null || _toCoords == null) return;
    setState(() { _calculatingRoute = true; _routePoints.clear(); _distanceKm = null; _durationMin = null; });
    try {
      final url = Uri.parse("https://router.project-osrm.org/route/v1/driving/${_fromCoords!.longitude},${_fromCoords!.latitude};${_toCoords!.longitude},${_toCoords!.latitude}?overview=full&geometries=geojson");
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] == null || (data['routes'] as List).isEmpty) throw Exception("No route found");
        final route  = data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;
        setState(() {
          _distanceKm  = route['distance'] / 1000;
          _durationMin = route['duration'] / 60;
          _routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        });
        if (_routePoints.isNotEmpty && mounted) {
          final bounds = LatLngBounds.fromPoints(_routePoints);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
          });
        }
      }
    } catch (e) { _showError("Failed to calculate route.");
    } finally { setState(() => _calculatingRoute = false); }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EnhancedMapPicker()));
    if (result != null && result is Map<String, dynamic>) {
      final address = result['address'] as String?;
      final coords  = result['latLng'] as LatLng?;
      if (address != null && coords != null) {
        setState(() { _toCtrl.text = address; _toCoords = coords; });
        await _calculateRouteInfo();
      }
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: T.yellow, onPrimary: T.txtDark, surface: T.card, onSurface: T.txtDark)), child: child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: T.yellow, onPrimary: T.txtDark, surface: T.card, onSurface: T.txtDark)), child: child!),
    );
    if (time == null) return;
    setState(() => _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  // ✅ _postRide with driverUPI properly fetched here
  Future<void> _postRide() async {
    if (!_formKey.currentState!.validate()) { _showError("Please fill all required fields"); return; }
    if (_selectedDateTime == null) { _showError("Please select date and time"); return; }
    if (_fromCoords == null || _toCoords == null) { _showError("Please select both pickup and destination locations"); return; }
    if (_selectedDateTime!.isBefore(DateTime.now())) { _showError("Please select a future date and time"); return; }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Fetch user doc — name AND upiId in one call 🔥
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String userName = "Unknown";
      if (userDoc.exists && userDoc.data()?['name'] != null) userName = userDoc['name'];
      else if (user.displayName?.isNotEmpty ?? false) userName = user.displayName!;
      else if (user.email?.contains('@') ?? false) userName = user.email!.split('@').first;

      // ✅ Fetch driver's UPI from user doc
      final driverUPI = userDoc.data()?['upiId'] ?? '';

      final seats   = int.tryParse(_seatsCtrl.text.trim()) ?? 1;
      final estCost = (_distanceKm != null ? _distanceKm! * 3 : 20) * seats;

      await FirebaseFirestore.instance.collection('rides').add({
        'from': _fromCtrl.text.trim(), 'to': _toCtrl.text.trim(),
        'from_lat': _fromCoords!.latitude, 'from_lng': _fromCoords!.longitude,
        'to_lat': _toCoords!.latitude, 'to_lng': _toCoords!.longitude,
        'seats': seats, 'remainingSeats': seats, 'rideType': _selectedRideType,
        'allowMultiple': _allowMultiple, 'distance_km': _distanceKm,
        'duration_min': _durationMin, 'estimatedCost': estCost.round(),
        'dateTime': _selectedDateTime, 'status': 'pending',
        'riderId': user.uid, 'postedByName': userName,
        'driverUPI': driverUPI,       // ✅ saved to ride doc for payment
        'paymentStatus': 'pending',   // ✅ payment tracking
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSuccess("Ride posted successfully!");
      _formKey.currentState!.reset();
      _fromCtrl.clear(); _toCtrl.clear(); _seatsCtrl.clear();
      setState(() {
        _selectedDateTime = null; _fromCoords = null; _toCoords = null;
        _distanceKm = null; _durationMin = null; _routePoints.clear();
        _selectedRideType = "Car"; _allowMultiple = true;
      });
      _autoDetectCurrentLocation();
    } catch (e) { _showError("Error posting ride: ${e.toString()}");
    } finally { setState(() => _isLoading = false); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: T.txtWhite, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: T.txtWhite, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: T.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: T.txtDark, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: T.txtDark, fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: T.yellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dtText = _selectedDateTime == null
        ? "Tap to select"
        : DateFormat('MMM dd, yyyy  •  hh:mm a').format(_selectedDateTime!);

    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(children: [
        SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(
              child: _loadingMap
                  ? _buildLoading()
                  : FadeTransition(
                opacity: _fade,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      _buildPageTitleRow(),
                      const SizedBox(height: 20),
                      if (!_loadingSavedRoutes && _savedRoutes.isNotEmpty) ...[
                        _buildSavedRoutesSection(),
                        const SizedBox(height: 20),
                      ],
                      _buildInfoBanner(),
                      const SizedBox(height: 16),
                      _buildLocationCard(
                        controller: _fromCtrl,
                        hint: "Pickup location",
                        icon: Icons.location_on,
                        iconColor: T.yellow,
                        readOnly: true,
                        helperText: "Tap refresh icon to re-detect",
                        validator: (v) => (v == null || v.isEmpty) ? "Location not detected" : null,
                      ),
                      const SizedBox(height: 12),
                      _buildLocationCard(
                        controller: _toCtrl,
                        hint: "Where do you want to go?",
                        icon: Icons.location_on,
                        iconColor: T.yellow,
                        readOnly: true,
                        helperText: "Tap icon to select destination",
                        trailing: GestureDetector(
                          onTap: _pickDestination,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.map, color: T.txtWhite, size: 18),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? "Please select destination" : null,
                      ),
                      const SizedBox(height: 16),
                      if (_calculatingRoute)
                        _buildInfoBannerRaw(icon: Icons.autorenew, msg: "Calculating route...", showLoader: true)
                      else if (_distanceKm != null && _durationMin != null) ...[
                        _buildRouteStats(),
                        const SizedBox(height: 10),
                        _buildSaveRouteBtn(),
                      ],
                      const SizedBox(height: 20),
                      _buildRideTypeCard(),
                      const SizedBox(height: 12),
                      _buildSeatsCard(),
                      const SizedBox(height: 12),
                      if (_selectedRideType == "Car") _buildMultipleToggle(),
                      const SizedBox(height: 12),
                      _buildDateTimeCard(dtText),
                      const SizedBox(height: 20),
                      if (_fromCoords != null) ...[
                        _buildMap(),
                        const SizedBox(height: 20),
                      ],
                      _buildPostBtn(),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: T.card, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: T.shadow, blurRadius: 20)]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 60, height: 60,
                      decoration: BoxDecoration(color: T.yellow, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.local_taxi, color: T.txtDark, size: 34)),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: T.yellow, strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  const Text("Posting your ride...", style: TextStyle(color: T.txtDark, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: T.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.directions_car, color: T.yellow, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text("GharTak",
              style: TextStyle(color: T.txtWhite, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        GestureDetector(
          onTap: _loadingMap ? null : _autoDetectCurrentLocation,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8)],
            ),
            child: const Icon(Icons.my_location, color: T.txtDark, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildPageTitleRow() {
    return Row(children: [
      const Expanded(
        child: Text("Post a Ride",
            style: TextStyle(color: T.txtDark, fontSize: 26, fontWeight: FontWeight.w800)),
      ),
      if (widget.prefilledRoute != null)
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: T.yellowDim,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: T.yellow.withOpacity(0.5)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bookmark, color: T.yellow, size: 12),
            SizedBox(width: 4),
            Text("Saved", style: TextStyle(color: T.txtDark, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 68, height: 68,
            decoration: BoxDecoration(color: T.yellow, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.local_taxi, color: T.txtDark, size: 40)),
        const SizedBox(height: 18),
        const CircularProgressIndicator(color: T.yellow, strokeWidth: 2.5),
        const SizedBox(height: 12),
        const Text("Detecting your location...", style: TextStyle(color: T.txtMed, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildInfoBanner() {
    final isPrefill = widget.prefilledRoute != null;
    return _buildInfoBannerRaw(
      icon: isPrefill ? Icons.bookmark_rounded : Icons.location_on,
      msg: isPrefill
          ? "Loaded from saved route — adjust if needed."
          : "Your current location is auto-detected. Just select your destination!",
    );
  }

  Widget _buildInfoBannerRaw({required IconData icon, required String msg, bool showLoader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: T.navyCard, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: T.yellow.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: T.yellow, width: 1.5),
          ),
          child: showLoader
              ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: T.yellow, strokeWidth: 2))
              : Icon(icon, color: T.yellow, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(msg,
            style: const TextStyle(color: T.txtWhite, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
      ]),
    );
  }

  Widget _buildSavedRoutesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bookmark, color: T.txtDark, size: 16),
        const SizedBox(width: 8),
        const Text("Saved Routes",
            style: TextStyle(color: T.txtDark, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: T.yellow, borderRadius: BorderRadius.circular(20)),
          child: Text("${_savedRoutes.length}",
              style: const TextStyle(color: T.txtDark, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _savedRoutes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _buildRouteChip(_savedRoutes[i]),
        ),
      ),
    ]);
  }

  Widget _buildRouteChip(SavedRoute route) {
    String short(String a) {
      final p = a.split(',').first.trim();
      return p.length > 16 ? '${p.substring(0, 14)}…' : p;
    }
    final isActive = _fromCoords != null && _toCoords != null &&
        route.fromCoords != null && route.toCoords != null &&
        (route.fromCoords!.latitude - _fromCoords!.latitude).abs() < 0.001 &&
        (route.toCoords!.latitude  - _toCoords!.latitude).abs()  < 0.001;

    return GestureDetector(
      onTap: () => _applySavedRoute(route),
      onLongPress: () => _showDeleteDialog(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? T.yellow : T.border, width: isActive ? 1.5 : 1),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: T.yellow, shape: BoxShape.circle,
                    border: Border.all(color: T.txtDark, width: 1.5))),
            const SizedBox(width: 8),
            Expanded(child: Text(
                route.nickname?.isNotEmpty == true ? route.nickname! : short(route.fromAddress),
                style: const TextStyle(color: T.txtDark, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          ]),
          Padding(padding: const EdgeInsets.only(left: 4.5),
              child: Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(vertical: 3), color: T.border)),
          Row(children: [
            const Icon(Icons.location_on, color: T.yellow, size: 13),
            const SizedBox(width: 5),
            Expanded(child: Text(short(route.toAddress),
                style: const TextStyle(color: T.txtMed, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: () => _showDeleteDialog(route),
                child: const Icon(Icons.close, color: T.txtLight, size: 14)),
          ]),
        ]),
      ),
    );
  }

  void _showDeleteDialog(SavedRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Route?", style: TextStyle(color: T.txtDark, fontWeight: FontWeight.w800)),
        content: Text("${route.fromAddress.split(',').first} → ${route.toAddress.split(',').first}",
            style: const TextStyle(color: T.txtMed, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: T.txtMed))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: T.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(ctx); _deleteSavedRoute(route); },
            child: const Text("Remove", style: TextStyle(color: T.txtWhite, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool readOnly = false,
    String? helperText,
    Widget? trailing,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(color: T.txtDark, fontSize: 14, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            prefixIcon: Icon(icon, color: iconColor, size: 22),
            hintText: hint,
            hintStyle: const TextStyle(color: T.txtLight, fontSize: 14),
            suffixIcon: trailing != null
                ? Padding(padding: const EdgeInsets.only(right: 10), child: trailing)
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
      ),
      if (helperText != null)
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 5),
          child: Text(helperText, style: const TextStyle(color: T.txtLight, fontSize: 11, fontStyle: FontStyle.italic)),
        ),
    ]);
  }

  Widget _buildRouteStats() {
    final seats   = int.tryParse(_seatsCtrl.text) ?? 1;
    final estCost = (_distanceKm! * 3) * seats;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _statItem(Icons.straighten_rounded, "${_distanceKm!.toStringAsFixed(1)} km", "Distance"),
        Container(width: 1, height: 36, color: T.border),
        _statItem(Icons.timer_rounded, "${_durationMin!.toStringAsFixed(0)} min", "ETA"),
        Container(width: 1, height: 36, color: T.border),
        _statItem(Icons.currency_rupee_rounded, "₹${estCost.toStringAsFixed(0)}", "Est. Cost"),
      ]),
    );
  }

  Widget _statItem(IconData icon, String val, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: T.yellow, size: 20),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: T.txtDark, fontSize: 14, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: T.txtMed, fontSize: 10)),
    ]);
  }

  Widget _buildSaveRouteBtn() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _savingRoute ? null : _saveCurrentRoute,
        style: OutlinedButton.styleFrom(
          foregroundColor: T.txtDark,
          side: const BorderSide(color: T.border, width: 1.5),
          backgroundColor: T.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        icon: _savingRoute
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: T.txtDark))
            : const Icon(Icons.bookmark_add_outlined, size: 18, color: T.txtDark),
        label: Text(_savingRoute ? "Saving..." : "Save this Route",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.txtDark)),
      ),
    );
  }

  Widget _buildRideTypeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRideType,
          dropdownColor: T.surface,
          isExpanded: true,
          icon: const Icon(Icons.chevron_right, color: T.txtWhite, size: 22),
          items: ["Car", "Bike"].map((t) => DropdownMenuItem(
            value: t,
            child: Row(children: [
              Icon(t == "Car" ? Icons.directions_car : Icons.two_wheeler, color: T.yellow, size: 20),
              const SizedBox(width: 12),
              Text(t, style: const TextStyle(color: T.txtWhite, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          )).toList(),
          onChanged: (v) {
            setState(() {
              _selectedRideType = v;
              if (v == "Bike") {
                _seatsCtrl.text = "1";
                _allowMultiple = false;
              } else if (v == "Car") {
                if (_seatsCtrl.text.isEmpty || _seatsCtrl.text == "1") _seatsCtrl.text = "4";
                _allowMultiple = true;
              }
            });
          },
          selectedItemBuilder: (_) => ["Car", "Bike"].map((t) => Align(
            alignment: Alignment.centerLeft,
            child: Row(children: [
              Icon(t == "Car" ? Icons.directions_car : Icons.two_wheeler, color: T.yellow, size: 20),
              const SizedBox(width: 12),
              Text(t, style: const TextStyle(color: T.txtWhite, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildSeatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: _seatsCtrl,
        keyboardType: TextInputType.number,
        enabled: _selectedRideType == "Car",
        style: const TextStyle(color: T.txtDark, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          labelText: "Available Seats",
          labelStyle: const TextStyle(color: T.txtMed, fontSize: 13),
          prefixIcon: const Icon(Icons.event_seat, color: T.yellow, size: 20),
          hintText: _selectedRideType == "Bike" ? "1 (fixed)" : "e.g. 4",
          hintStyle: const TextStyle(color: T.txtLight, fontSize: 13),
          helperText: _selectedRideType == "Bike" ? "1 seat (fixed for bike)" : "Max 6 seats",
          helperStyle: const TextStyle(color: T.txtLight, fontSize: 11),
        ),
        onChanged: (_) { if (_distanceKm != null) setState(() {}); },
        validator: (v) {
          if (_selectedRideType == "Bike") return null;
          if (v == null || v.isEmpty) return "Enter number of seats";
          final s = int.tryParse(v);
          if (s == null || s < 1) return "Enter valid number";
          if (s > 6) return "Maximum 6 seats";
          return null;
        },
      ),
    );
  }

  Widget _buildMultipleToggle() {
    return Container(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.border),
        boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text("Allow Multiple Passengers",
            style: TextStyle(color: T.txtDark, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: const Text("Multiple people can book this ride",
            style: TextStyle(color: T.txtMed, fontSize: 11)),
        value: _allowMultiple,
        onChanged: (v) => setState(() => _allowMultiple = v),
        secondary: const Icon(Icons.group, color: T.yellow, size: 22),
        activeColor: T.txtWhite,
        activeTrackColor: T.yellow,
        inactiveThumbColor: T.txtLight,
        inactiveTrackColor: T.border,
      ),
    );
  }

  Widget _buildDateTimeCard(String dtText) {
    final picked = _selectedDateTime != null;
    return GestureDetector(
      onTap: _pickDateTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: picked ? T.yellowDim : T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: picked ? T.yellow : T.border, width: picked ? 1.5 : 1),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, color: picked ? T.yellow : T.txtMed, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Departure Time",
                style: TextStyle(color: T.txtMed, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(dtText, style: TextStyle(
              color: picked ? T.txtDark : T.txtLight,
              fontSize: 14,
              fontWeight: picked ? FontWeight.w700 : FontWeight.normal,
            )),
          ])),
          Icon(Icons.chevron_right, color: picked ? T.yellow : T.txtLight, size: 20),
        ]),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border),
          boxShadow: [BoxShadow(color: T.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fromCoords!, initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ghartak.app'),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 4, color: T.yellow)]),
              MarkerLayer(markers: [
                Marker(point: _fromCoords!, width: 36, height: 36, child: const Icon(Icons.my_location_rounded, color: Colors.green, size: 32)),
                if (_toCoords != null)
                  Marker(point: _toCoords!, width: 36, height: 36, child: Icon(Icons.location_on, color: T.yellow, size: 36)),
              ]),
            ],
          ),
          Positioned(top: 8, right: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(8)),
            child: const Text("LIVE MAP", style: TextStyle(color: T.yellow, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          )),
        ]),
      ),
    );
  }

  Widget _buildPostBtn() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _postRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: T.yellow,
          foregroundColor: T.txtDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: T.yellow.withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: T.txtDark))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.local_taxi, size: 20, color: T.txtDark),
          SizedBox(width: 10),
          Text("Post Ride", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.txtDark, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}