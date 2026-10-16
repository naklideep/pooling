import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pooling_header.dart';
import '../../core/widgets/loading_states.dart';
import '../../data/models/invitation_model.dart';
import '../../data/repositories/invitation_repository.dart';
import 'send_invitation_sheet.dart';

/// Invitations Center for viewing, accepting, declining, and managing direct ride invitations.
class InvitationsPage extends StatefulWidget {
  final String userId;

  const InvitationsPage({super.key, required this.userId});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _invRepo = InvitationRepository();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showClaimCodeDialog() {
    final codeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Redeem Invitation Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Have a shareable ride invite code? Enter it below to claim your seat reservation.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. POOL-8921',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);

              final inv = await _invRepo.getInvitationByCode(code);
              if (!mounted) return;

              if (inv == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid invitation code.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              _acceptInvite(inv);
            },
            child: const Text('Claim Seat'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvite(InvitationModel invite) async {
    final user = FirebaseAuth.instance.currentUser!;
    final res = await _invRepo.acceptInvitation(
      invitationId: invite.id,
      acceptingUserId: user.uid,
      acceptingUserName: user.displayName ?? 'Passenger',
      acceptingUserPhoto: user.photoURL,
    );

    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Invitation accepted! Seat confirmed.'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Failed to accept invitation.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Send Invite'),
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SendInvitationSheet(publisherId: widget.userId),
          );
        },
      ),
      body: Column(
        children: [
          PoolingHeader(
            subtitle: 'Ride Invitations Center',
            trailing: IconButton(
              icon: const Icon(Icons.vpn_key_outlined, color: Colors.white),
              tooltip: 'Redeem Code',
              onPressed: _showClaimCodeDialog,
            ),
          ),
          // Tab bar
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.navy,
              indicatorWeight: 3,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Incoming Invites'),
                Tab(text: 'Sent Invites'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildIncomingTab(),
                _buildSentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTab() {
    return StreamBuilder<List<InvitationModel>>(
      stream: _invRepo.streamIncomingInvitations(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyStateView(
            icon: Icons.mark_email_read_outlined,
            title: 'No pending invitations',
            subtitle:
                'When drivers or friends invite you to join their ride, invitations will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = list[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.yellow, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x06000000),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.yellow.withValues(alpha: 0.2),
                            backgroundImage: item.publisherPhoto != null
                                ? NetworkImage(item.publisherPhoto!)
                                : null,
                            child: item.publisherPhoto == null
                                ? const Icon(Icons.person, size: 16, color: AppColors.navy)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.publisherName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.seatsOffered} seat(s) reserved',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.from} → ${item.to}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.rideDateTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, MMM d · hh:mm a').format(item.rideDateTime!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            await _invRepo.declineInvitation(
                              invitationId: item.id,
                              decliningUserId: widget.userId,
                            );
                          },
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _acceptInvite(item),
                          child: const Text(
                            'Accept & Book',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSentTab() {
    return StreamBuilder<List<InvitationModel>>(
      stream: _invRepo.streamSentInvitations(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyStateView(
            icon: Icons.send_outlined,
            title: 'No invitations sent yet',
            subtitle:
                'Tap "+ Send Invite" below to personally invite friends, colleagues, or subscribers to your rides.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = list[i];
            final isPending = item.status == InvitationStatus.pending;

            Color statusColor;
            switch (item.status) {
              case InvitationStatus.accepted:
                statusColor = const Color(0xFF2E7D32);
                break;
              case InvitationStatus.declined:
              case InvitationStatus.revoked:
                statusColor = Colors.red;
                break;
              case InvitationStatus.expired:
                statusColor = Colors.grey;
                break;
              case InvitationStatus.pending:
                statusColor = AppColors.navy;
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.recipientName ?? item.recipientEmail ?? 'Invited Rider',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.from} → ${item.to}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shareable code chip
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: item.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${item.inviteCode} to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.copy_rounded, size: 14, color: AppColors.navy),
                              const SizedBox(width: 6),
                              Text(
                                item.inviteCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isPending)
                        TextButton(
                          onPressed: () async {
                            await _invRepo.revokeInvitation(
                              invitationId: item.id,
                              publisherId: widget.userId,
                            );
                          },
                          child: const Text('Revoke', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
