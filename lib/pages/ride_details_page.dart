// ride_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_ride_tracking_page.dart';
import 'live_tracking_service.dart';

class RideDetailsPage extends StatefulWidget {
  final String rideId;
  const RideDetailsPage({super.key, required this.rideId});

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final isOwner = data['riderId'] == (/* current user */ null); // leave null, use logic where you call this page
        final status = data['status'] ?? 'pending';

        return Scaffold(
          appBar: AppBar(title: const Text('Ride Details')),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${data['from'] ?? 'Unknown'} ➝ ${data['to'] ?? 'Unknown'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Posted by: ${data['postedByName'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Seats: ${data['remainingSeats'] ?? data['seats'] ?? 0}'),
                const SizedBox(height: 8),
                Text('Status: $status'),
                const Spacer(),
                Row(
                  children: [
                    if (data['startLat'] != null && data['destLat'] != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveRideTrackingPage(
                                rideId: widget.rideId,
                                startLat: (data['startLat'] as num).toDouble(),
                                startLng: (data['startLng'] as num).toDouble(),
                                destLat: (data['destLat'] as num).toDouble(),
                                destLng: (data['destLng'] as num).toDouble(),
                                isDriver: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Track Live'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // If current user is the poster they should start tracking
                        await LiveTrackingService.instance.start(widget.rideId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking started (foreground)')));
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start (Driver)'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await LiveTrackingService.instance.stop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking stopped')));
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
