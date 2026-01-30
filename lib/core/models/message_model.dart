import 'package:uuid/uuid.dart';

enum MessageType { text, image, file, handshake }

class MessageModel {
  final String id;
  final String senderId; // "me" or device address
  final String content;
  final MessageType type;
  final int timestamp;
  final bool isMe; // Helper for UI

  MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isMe = false,
  });

  factory MessageModel.create({
    required String content,
    required bool isMe,
    MessageType type = MessageType.text,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      senderId: isMe ? "SELF" : "OTHER", // In real app, use actual IDs
      content: content,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isMe: isMe,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      's': senderId,
      'c': content,
      't': type.index,
      'ts': timestamp,
    };
  }

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    bool isMe = false,
  }) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['s'] as String,
      content: json['c'] as String,
      type: MessageType.values[json['t'] as int],
      timestamp: json['ts'] as int,
      isMe: isMe,
    );
  }
}
