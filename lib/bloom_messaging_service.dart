import 'dart:convert';

import 'package:http/http.dart' as http;

class BloomConversation {
  final String id;
  final String userA;
  final String userB;
  final String otherUserId;
  final String otherName;
  final String otherUsername;
  final String otherPhotoUrl;
  final String lastMessage;
  final String lastMessageAt;
  final int unreadCount;

  const BloomConversation({
    required this.id,
    required this.userA,
    required this.userB,
    required this.otherUserId,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory BloomConversation.fromJson(Map<String, dynamic> json) {
    return BloomConversation(
      id: '${json['id'] ?? ''}',
      userA: '${json['user_a'] ?? ''}',
      userB: '${json['user_b'] ?? ''}',
      otherUserId: '${json['other_user_id'] ?? ''}',
      otherName: '${json['other_name'] ?? ''}',
      otherUsername: '${json['other_username'] ?? ''}',
      otherPhotoUrl: '${json['other_photo_url'] ?? ''}',
      lastMessage: '${json['last_message'] ?? ''}',
      lastMessageAt: '${json['last_message_at'] ?? ''}',
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
    );
  }
}

class BloomMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String body;
  final bool isRead;
  final String createdAt;

  const BloomMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory BloomMessage.fromJson(Map<String, dynamic> json) {
    return BloomMessage(
      id: '${json['id'] ?? ''}',
      conversationId: '${json['conversation_id'] ?? ''}',
      senderId: '${json['sender_id'] ?? ''}',
      receiverId: '${json['receiver_id'] ?? ''}',
      body: '${json['body'] ?? ''}',
      isRead: '${json['is_read'] ?? 0}' == '1',
      createdAt: '${json['created_at'] ?? ''}',
    );
  }
}

class BloomMessagingService {
  final String baseUrl;

  const BloomMessagingService({
    required this.baseUrl,
  });

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<BloomConversation> createConversation({
    required String userId,
    required String otherUserId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/conversations'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'other_user_id': otherUserId,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error'] ?? 'Gagal membuat percakapan',
      );
    }

    final conversation = data['conversation'];

    if (conversation is! Map) {
      throw Exception('Data percakapan tidak valid');
    }

    return BloomConversation.fromJson(
      Map<String, dynamic>.from(conversation),
    );
  }

  Future<List<BloomConversation>> getConversations({
    required String userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/conversations',
    ).replace(
      queryParameters: {
        'user_id': userId,
      },
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error'] ?? 'Gagal mengambil percakapan',
      );
    }

    final rows = data['conversations'];

    if (rows is! List) {
      return const [];
    }

    return rows
        .whereType<Map>()
        .map(
          (item) => BloomConversation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<BloomMessage>> getMessages({
    required String userId,
    required String conversationId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/messages',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'conversation_id': conversationId,
      },
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error'] ?? 'Gagal mengambil pesan',
      );
    }

    final rows = data['messages'];

    if (rows is! List) {
      return const [];
    }

    return rows
        .whereType<Map>()
        .map(
          (item) => BloomMessage.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<BloomMessage> sendMessage({
    required String senderId,
    required String receiverId,
    required String conversationId,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Pesan tidak boleh kosong');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/messages'),
      headers: _headers,
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'conversation_id': conversationId,
        'body': text,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error'] ?? 'Gagal mengirim pesan',
      );
    }

    final message = data['message'];

    if (message is! Map) {
      throw Exception('Data pesan tidak valid');
    }

    return BloomMessage.fromJson(
      Map<String, dynamic>.from(message),
    );
  }

  Future<int> markMessagesRead({
    required String userId,
    required String conversationId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/read'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'conversation_id': conversationId,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error'] ?? 'Gagal menandai pesan telah dibaca',
      );
    }

    return int.tryParse('${data['updated'] ?? 0}') ?? 0;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {
        'ok': false,
        'error': 'invalid_api_response',
      };
    } catch (_) {
      return {
        'ok': false,
        'error': 'invalid_json_response',
      };
    }
  }
}
