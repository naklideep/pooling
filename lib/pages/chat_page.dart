import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String rideId;
  const ChatPage({required this.rideId, Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color kNavy = Color(0xFF1A2340);
  static const Color kYellow = Color(0xFFFFCC00);
  static const Color kBackground = Color(0xFFEEF0F5);

  bool _isTyping = false;
  List<String> _typingUsers = [];
  Map<String, dynamic> _userCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenTypingStatus();
    _loadUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _updateTyping(false);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final rideDoc = await _firestore.collection('rides').doc(widget.rideId).get();
      if (rideDoc.exists) {
        final participants = rideDoc.data()?['participants'] as List<dynamic>? ?? [];
        for (var userId in participants) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            _userCache[userId] = userDoc.data();
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _listenTypingStatus() {
    _firestore
        .collection('rides')
        .doc(widget.rideId)
        .collection('typing')
        .snapshots()
        .listen((snapshot) {
      final typingUsersList = snapshot.docs
          .where((doc) => doc.id != _auth.currentUser!.uid && doc['typing'] == true)
          .map((doc) => doc.id)
          .toList();
      setState(() {
        _typingUsers = typingUsersList;
        _isTyping = typingUsersList.isNotEmpty;
      });
    });
  }

  void _updateTyping(bool typing) {
    _firestore
        .collection('rides')
        .doc(widget.rideId)
        .collection('typing')
        .doc(_auth.currentUser!.uid)
        .set({
      'typing': typing,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('rides')
          .doc(widget.rideId)
          .collection('chats')
          .add({
        'senderId': _auth.currentUser!.uid,
        'senderName': _auth.currentUser!.displayName ?? 'Unknown',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [_auth.currentUser!.uid],
        'edited': false,
      });

      _messageController.clear();
      _updateTyping(false);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send message');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _filterProfanity(String text) {
    final banned = ['badword1', 'badword2', 'spam', 'offensive'];
    String filtered = text;
    for (var word in banned) {
      filtered = filtered.replaceAll(
        RegExp(word, caseSensitive: false),
        '*' * word.length,
      );
    }
    return filtered;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return 'Sending...';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) return DateFormat('hh:mm a').format(date);
    if (diff.inDays == 1) return 'Yesterday ${DateFormat('hh:mm a').format(date)}';
    if (diff.inDays < 7) return DateFormat('EEE hh:mm a').format(date);
    return DateFormat('MMM d, hh:mm a').format(date);
  }

  String _getUserName(String userId) {
    return _userCache[userId]?['name'] ?? 'User';
  }

  Widget _buildMessageTile(DocumentSnapshot doc) {
    final msg = doc.data()! as Map<String, dynamic>;
    final isMe = msg['senderId'] == _auth.currentUser!.uid;
    final time = _formatTime(msg['timestamp']);
    final senderName = _getUserName(msg['senderId']);
    final readCount = (msg['readBy'] as List<dynamic>?)?.length ?? 1;

    return GestureDetector(
      onLongPress: isMe ? () => _showMessageOptions(doc) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? kNavy : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    _filterProfanity(msg['message']),
                    style: TextStyle(
                      color: isMe ? Colors.white : kNavy,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          readCount > 1 ? Icons.done_all : Icons.done,
                          size: 13,
                          color: readCount > 1 ? kYellow : Colors.white.withOpacity(0.5),
                        ),
                      ],
                      if (msg['edited'] == true) ...[
                        const SizedBox(width: 4),
                        Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.5)
                                : Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(
                      color: kNavy, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(doc);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(DocumentSnapshot doc) async {
    try {
      await doc.reference.delete();
    } catch (e) {
      _showError('Failed to delete message');
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                ),
                title: const Text(
                  'Clear Chat',
                  style: TextStyle(
                      color: kNavy, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Delete all messages',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearChat();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              "Clear Chat?",
              style: TextStyle(
                  color: kNavy, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete all messages? This cannot be undone.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    setState(() => _isLoading = true);
    try {
      final chatCollection = _firestore
          .collection('rides')
          .doc(widget.rideId)
          .collection('chats');
      final snapshot = await chatCollection.get();
      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Chat cleared successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF43A047),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      _showError('Failed to clear chat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value + index * 0.3) % 1.0,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: kNavy,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rides')
                  .doc(widget.rideId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Something went wrong',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: kNavy));
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chat_bubble_outline,
                              size: 48, color: kNavy),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                              color: kNavy,
                              fontSize: 17,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildTypingIndicator();

                    final msg = messages[index - 1];
                    final msgData = msg.data()! as Map<String, dynamic>;

                    if (!(msgData['readBy'] as List).contains(_auth.currentUser!.uid)) {
                      msg.reference.update({
                        'readBy': FieldValue.arrayUnion([_auth.currentUser!.uid])
                      });
                    }

                    return _buildMessageTile(msg);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      color: kNavy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chat_bubble, color: kNavy, size: 18),
          ),
          const SizedBox(width: 10),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ride Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isTyping)
                  Text(
                    _typingUsers.length == 1
                        ? 'Someone is typing...'
                        : '${_typingUsers.length} people typing...',
                    style: TextStyle(
                      color: kYellow.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // More options
          GestureDetector(
            onTap: _showChatOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: kNavy, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (text) => _updateTyping(text.isNotEmpty),
                  onSubmitted: (_) => sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isLoading ? null : sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: kYellow,
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: kNavy, strokeWidth: 2),
                )
                    : const Icon(Icons.send_rounded, color: kNavy, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}