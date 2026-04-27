import 'dart:typed_data';

enum Role { user, bot }

class ChatImageAttachment {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  ChatImageAttachment({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
}

class ChatMessage {
  final String text;
  final Role role;
  final DateTime createdAt;
  final List<String> imageUrls;
  final List<ChatImageAttachment> localImages;

  ChatMessage({
    required this.text,
    required this.role,
    this.imageUrls = const [],
    this.localImages = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasImages => imageUrls.isNotEmpty || localImages.isNotEmpty;
}
