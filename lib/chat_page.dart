import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:khuje_nao/api_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final InMemoryChatController _chatController = InMemoryChatController();
  final STORAGE = const FlutterSecureStorage();
  final ApiService api_service = ApiService();
  String currentUserId = '';
  String current_receiver = '';
  Map<String, dynamic>? receiver_details;
  bool is_loading = true;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    initializeUser();
  }

  @override
  void dispose() {
    api_service.offNewMessage();
    api_service.disconnectSocket();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> initializeUser() async {
    try {
      final email = await STORAGE.read(key: "email");
      final receiverEmail = await STORAGE.read(key: "receiver_email");

      if (email != null && receiverEmail != null) {
        setState(() {
          currentUserId = email;
          current_receiver = receiverEmail;
          is_loading = false;
        });

        await fetchReceiverDetails();
        await loadMessages();
        setupSocketListener();
        
        // Connect socket and join room
        api_service.connectSocket();
        api_service.joinChatRoom(currentUserId, current_receiver);

        await api_service.markMessagesRead(
          authorId: current_receiver,
          receiverId: currentUserId,
        );
      } else {
        throw Exception("User or receiver email not found in storage.");
      }
    } catch (e) {
      debugPrint("Error initializing chat: $e");
      setState(() {
        is_loading = false;
      });
    }
  }

  Future<void> fetchReceiverDetails() async {
    try {
      final details = await api_service.getUserByEmail(current_receiver);
      setState(() {
        receiver_details = details;
      });
    } catch (e) {
      debugPrint('Error fetching receiver details: $e');
    }
  }

  void setupSocketListener() {
    api_service.onNewMessage((data) {
      if (mounted) {
        final message = Message.text(
          id: data['id'] ?? '',
          authorId: data['author_id'] ?? '',
          createdAt: DateTime.parse(data['created_at']),
          text: data['text'] ?? '',
        );
        
        final existingIds = _chatController.messages.map((m) => m.id).toSet();
        if (!existingIds.contains(message.id)) {
          _chatController.insertMessage(message);
        }
      }
    });
  }

  Future<void> loadMessages() async {
    try {
      final messages = await api_service.getMessages(
        authorId: currentUserId,
        receiverId: current_receiver,
      );

      final loadedMessages = messages.map((msg) {
        return Message.text(
          id: msg['_id'] ?? msg['id'] ?? '',
          authorId: msg['author_id'] ?? '',
          createdAt: DateTime.parse(msg['created_at']),
          text: msg['text'] ?? '',
        );
      }).toList();

      loadedMessages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      await _chatController.setMessages(loadedMessages, animated: false);
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _handleSendPressed(String text) async {
    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final message = Message.text(
      id: messageId,
      authorId: currentUserId,
      createdAt: now,
      text: text,
    );

    _chatController.insertMessage(message);
    
    // Send via SocketIO
    api_service.sendMessageViaSocket(
      authorId: currentUserId,
      receiverId: current_receiver,
      text: text,
    );
  }

  void showReceiverDetailsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contact Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (receiver_details != null) ...[
                  if (receiver_details!['name'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Name: ${receiver_details!['name']}')),
                        ],
                      ),
                    ),
                  if (receiver_details!['email'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.email, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Email: ${receiver_details!['email']}')),
                        ],
                      ),
                    ),
                  if (receiver_details!['nsu_id'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.badge, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(child: Text('NSU ID: ${receiver_details!['nsu_id']}')),
                        ],
                      ),
                    ),
                  if (receiver_details!['phone_number'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.phone, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Phone: ${receiver_details!['phone_number']}')),
                        ],
                      ),
                    ),
                ] else
                  const Text('Loading contact information...'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (is_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${receiver_details?['name'] ?? current_receiver.split('@').first}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: showReceiverDetailsDialog,
            tooltip: 'View contact information',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Text(
                'Offline - messages will send when connected',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (receiver_details != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (receiver_details!['nsu_id'] != null)
                        Text('NSU ID: ${receiver_details!['nsu_id']}', style: const TextStyle(fontSize: 12)),
                      if (receiver_details!['phone_number'] != null)
                        Text('Phone: ${receiver_details!['phone_number']}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: Chat(
              currentUserId: currentUserId,
              chatController: _chatController,
              resolveUser: _resolveUser,
              onMessageSend: _handleSendPressed,
            ),
          ),
        ],
      ),
    );
  }

  Future<User?> _resolveUser(String userId) async {
    if (userId == currentUserId) {
      return User(
        id: currentUserId,
        name: currentUserId.split('@').first,
      );
    }
    if (userId == current_receiver) {
      return User(
        id: current_receiver,
        name: receiver_details?['name'] ?? current_receiver.split('@').first,
      );
    }
    return null;
  }
}
