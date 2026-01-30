import 'dart:async';
import 'package:bluetooth_connectivity/core/bluetooth/bluetooth_service.dart';
import 'package:bluetooth_connectivity/core/models/message_model.dart';
import 'package:bluetooth_connectivity/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const ChatScreen({super.key, this.device});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  StreamSubscription<MessageModel>? _messageSubscription;

  bool get isConnected => _bluetoothService.isConnected;

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  void _connectAndListen() async {
    // If we're client, we might need to connect first.
    // Ideally this screen receives an already connected socket,
    // but for now we assume global service holds the connection.
    _setupMessageListener();
  }

  void _setupMessageListener() {
    _messageSubscription = _bluetoothService.messageStream?.listen(
      (message) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      },
      onError: (error) {
        debugPrint("Error receiving message: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $error"),
            backgroundColor: AppTheme.error,
          ),
        );
      },
      onDone: () {
        debugPrint("Connection closed");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Disconnected"),
            backgroundColor: AppTheme.error,
          ),
        );
      },
    );
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    if (!isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not connected")));
      return;
    }

    final text = _textController.text.trim();
    final message = MessageModel.create(content: text, isMe: true);

    try {
      await _bluetoothService.sendMessage(message);
      setState(() {
        _messages.add(message);
        _textController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Add a bit of buffer
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    // We do NOT disconnect the service here,
    // because we might want to go back to explore, or keep connection alive.
    // Disconnect happens on specific user action or error.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.device?.name ?? "Chat";

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(title),
            if (isConnected)
              const Text(
                "Connected",
                style: TextStyle(fontSize: 12, color: Colors.greenAccent),
              )
            else
              const Text(
                "Disconnected",
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show device details or session info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("No messages yet. Say hi!"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Attachments (Image/File) implementation later
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: AppTheme.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final timeStr = DateFormat(
      'HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(message.timestamp));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(0),
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }
}
