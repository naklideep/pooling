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

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Load user data for display names and avatars
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

  // Listen to typing status of other users
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

  // Update typing status with debouncing
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

  // Send text message with validation
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

  // Enhanced profanity filter
  String _filterProfanity(String text) {
    final banned = [
      'badword1', 'badword2', 'spam', 'offensive'
    ];
    String filtered = text;
    for (var word in banned) {
      filtered = filtered.replaceAll(
        RegExp(word, caseSensitive: false),
        '*' * word.length,
      );
    }
    return filtered;
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Format timestamp
  String _formatTime(Timestamp? ts) {
    if (ts == null) return 'Sending...';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat('hh:mm a').format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('hh:mm a').format(date)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE hh:mm a').format(date);
    } else {
      return DateFormat('MMM d, hh:mm a').format(date);
    }
  }

  // Get user name from cache
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[600] : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
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
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          readCount > 1 ? Icons.done_all : Icons.done,
                          size: 14,
                          color: readCount > 1 ? Colors.blue[200] : Colors.white70,
                        ),
                      ],
                      if (msg['edited'] == true) ...[
                        const SizedBox(width: 4),
                        Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 9,
                            color: isMe ? Colors.white60 : Colors.black45,
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

  // Show message options (delete, edit)
  void _showMessageOptions(DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Delete message
  Future<void> _deleteMessage(DocumentSnapshot doc) async {
    try {
      await doc.reference.delete();
    } catch (e) {
      _showError('Failed to delete message');
    }
  }

  // Build typing indicator
  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
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
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
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
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.blue[600],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride Chat', style: TextStyle(fontSize: 18)),
            if (_isTyping)
              Text(
                _typingUsers.length == 1
                    ? 'Someone is typing...'
                    : '${_typingUsers.length} people are typing...',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildTypingIndicator();
                    }

                    final msg = messages[index - 1];
                    final msgData = msg.data()! as Map<String, dynamic>;

                    // Mark as read
                    if (!msgData['readBy'].contains(_auth.currentUser!.uid)) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
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
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (text) => _updateTyping(text.isNotEmpty),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _isLoading ? null : sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}