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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _listenTypingStatus();
  }

  // Listen to typing status of other users
  void _listenTypingStatus() {
    _firestore
        .collection('rides')
        .doc(widget.rideId)
        .collection('typing')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _isTyping = snapshot.docs.any((doc) =>
        doc.id != _auth.currentUser!.uid && doc['typing'] == true);
      });
    });
  }

  // Update typing status
  void _updateTyping(bool typing) {
    _firestore
        .collection('rides')
        .doc(widget.rideId)
        .collection('typing')
        .doc(_auth.currentUser!.uid)
        .set({'typing': typing});
  }

  // Send text message
  Future<void> sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    await _firestore
        .collection('rides')
        .doc(widget.rideId)
        .collection('chats')
        .add({
      'senderId': _auth.currentUser!.uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [_auth.currentUser!.uid],
    });

    _messageController.clear();
    _updateTyping(false);
  }

  // Simple profanity filter
  String _filterProfanity(String text) {
    final banned = ['badword1', 'badword2']; // add more if needed
    String filtered = text;
    for (var word in banned) {
      filtered = filtered.replaceAll(RegExp(word, caseSensitive: false), '****');
    }
    return filtered;
  }

  Widget _buildMessageTile(Map<String, dynamic> msg) {
    bool isMe = msg['senderId'] == _auth.currentUser!.uid;
    Timestamp? ts = msg['timestamp'];
    String time = ts != null
        ? DateFormat('hh:mm a').format(ts.toDate())
        : 'Sending...';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              _filterProfanity(msg['message']),
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            Text(
              time,
              style: TextStyle(
                  fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride Chat'),
            if (_isTyping)
              const Text('Someone is typing...', style: TextStyle(fontSize: 12))
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
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data()! as Map<String, dynamic>;
                    if (!msg['readBy'].contains(_auth.currentUser!.uid)) {
                      messages[index].reference.update({
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onChanged: (text) => _updateTyping(text.isNotEmpty),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
