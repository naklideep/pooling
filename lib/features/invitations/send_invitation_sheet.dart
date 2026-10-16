import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ride_model.dart';
import '../../data/repositories/invitation_repository.dart';

/// Modal bottom sheet allowing publishers to search and invite riders to a ride or commute.
class SendInvitationSheet extends StatefulWidget {
  final String publisherId;
  final String? initialRideId;

  const SendInvitationSheet({
    super.key,
    required this.publisherId,
    this.initialRideId,
  });

  @override
  State<SendInvitationSheet> createState() => _SendInvitationSheetState();
}

class _SendInvitationSheetState extends State<SendInvitationSheet> {
  final _invRepo = InvitationRepository();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  Map<String, dynamic>? _selectedUser;
  RideModel? _selectedRide;
  List<RideModel> _publisherRides = [];
  bool _loadingRides = true;

  int _seatsOffered = 1;
  int _expiryHours = 48;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadPublisherRides();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPublisherRides() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('riderId', isEqualTo: widget.publisherId)
          .where('status', whereIn: ['pending', 'published'])
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final list = snap.docs.map((d) => RideModel.fromFirestore(d)).toList();
      if (!mounted) return;
      setState(() {
        _publisherRides = list;
        if (widget.initialRideId != null) {
          _selectedRide = list.firstWhere(
            (r) => r.id == widget.initialRideId,
            orElse: () => list.isNotEmpty ? list.first : list.first,
          );
        } else if (list.isNotEmpty) {
          _selectedRide = list.first;
        }
        _loadingRides = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRides = false);
    }
  }

  Future<void> _performSearch(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _invRepo.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _searchResults = results
          .where((u) => u['id'] != widget.publisherId)
          .toList();
      _searching = false;
    });
  }

  Future<void> _sendInvite() async {
    if (_selectedRide == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a ride to invite to.')),
      );
      return;
    }

    setState(() => _isSending = true);

    final user = FirebaseAuth.instance.currentUser!;
    String publisherName = user.displayName ?? 'Publisher';
    String? publisherPhoto = user.photoURL;

    final uDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (uDoc.exists) {
      publisherName = uDoc.data()?['name'] ?? publisherName;
      publisherPhoto = uDoc.data()?['photoUrl'] ?? publisherPhoto;
    }

    final res = await _invRepo.sendInvitation(
      publisherId: widget.publisherId,
      publisherName: publisherName,
      publisherPhoto: publisherPhoto,
      recipientId: _selectedUser?['id'],
      recipientName: _selectedUser?['name'] ?? 'Invited Rider',
      recipientEmail: _selectedUser?['email'],
      rideId: _selectedRide!.id,
      scheduleId: _selectedRide!.scheduleId,
      from: _selectedRide!.from,
      to: _selectedRide!.to,
      rideDateTime: _selectedRide!.dateTime,
      seatsOffered: _seatsOffered,
      validDuration: Duration(hours: _expiryHours),
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (res.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Invitation sent!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Failed to send invite.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
              const Text(
                'Invite a Rider',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search for users or generate a personal invite code.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),

              // Ride selector
              const Text(
                'Select Ride to Invite To:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (_loadingRides)
                const LinearProgressIndicator()
              else if (_publisherRides.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No active rides found. Create a ride first.'),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RideModel>(
                      value: _selectedRide,
                      isExpanded: true,
                      items: _publisherRides.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            '${r.from} → ${r.to} (${r.remainingSeats} seats left)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRide = val),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Search User Field
              const Text(
                'Search Rider (Name or Email):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchCtrl,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Type rider name…',
                  prefixIcon: const Icon(Icons.person_search_rounded),
                  suffixIcon: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Search results list
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) {
                      final u = _searchResults[i];
                      final isSelected = _selectedUser?['id'] == u['id'];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            (u['name'] as String? ?? 'U')[0].toUpperCase(),
                          ),
                        ),
                        title: Text(u['name'] ?? 'User'),
                        subtitle: Text(u['email'] ?? ''),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.navy)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedUser = u;
                            _searchCtrl.text = u['name'] ?? '';
                            _searchResults = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Seats & Expiry Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seats Offered:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _seatsOffered,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [1, 2, 3, 4]
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n seat(s)')))
                              .toList(),
                          onChanged: (v) => setState(() => _seatsOffered = v ?? 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expires In:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _expiryHours,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 24, child: Text('24 Hours')),
                            DropdownMenuItem(value: 48, child: Text('48 Hours')),
                            DropdownMenuItem(value: 72, child: Text('72 Hours')),
                          ],
                          onChanged: (v) => setState(() => _expiryHours = v ?? 48),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSending ? null : _sendInvite,
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Send Direct Invitation',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
