import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_connectivity/core/models/message_model.dart';
import 'package:flutter/foundation.dart';

class BluetoothProtocol {
  static const String DELIMITER =
      "\n"; // Simple newline delimiter for JSON stream

  /// Encodes a message to bytes with a delimiter
  Uint8List encode(MessageModel message) {
    final jsonString = jsonEncode(message.toJson());
    // Add the delimiter so the receiver knows when the packet ends
    final packet = "$jsonString$DELIMITER";
    return Uint8List.fromList(utf8.encode(packet));
  }

  /// Transforms a raw byte stream into a stream of MessageModels
  /// Handles fragmentation (partial messages arriving in chunks)
  StreamTransformer<Uint8List, MessageModel> get transformer {
    return StreamTransformer<Uint8List, MessageModel>.fromHandlers(
      handleData: (data, sink) {
        _buffer.addAll(data);

        // Check loops effectively to find all delimiters in current buffer
        while (true) {
          int index = -1;
          // Look for \n (10 in ASCII/UTF-8)
          for (int i = 0; i < _buffer.length; i++) {
            if (_buffer[i] == 10) {
              index = i;
              break;
            }
          }

          if (index == -1) {
            // No full message yet, wait for more data
            break;
          }

          // Extract the full packet up to the delimiter
          final packetBytes = _buffer.sublist(0, index);

          // Remove from buffer (including the delimiter itself which is index + 1)
          _buffer.removeRange(0, index + 1);

          try {
            final String jsonString = utf8.decode(packetBytes);
            if (jsonString.trim().isNotEmpty) {
              final Map<String, dynamic> json = jsonDecode(jsonString);
              // In this simple 'peer-to-peer' without auth, 'isMe' is always false for received messages
              final message = MessageModel.fromJson(json, isMe: false);
              sink.add(message);
            }
          } catch (e) {
            debugPrint("Protocol Error: Failed to parse packet: $e");
            // If corrupt, we just dropped the packet bytes from buffer already, so we move on.
          }
        }
      },
    );
  }

  // Internal buffer to hold partial data
  final List<int> _buffer = [];

  void clear() {
    _buffer.clear();
  }
}
