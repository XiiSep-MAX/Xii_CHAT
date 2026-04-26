enum Role { user, bot }

class ChatMessage {
  final String text;
  final Role role;
  final DateTime createdAt;
  final List<String> imageUrls;

  ChatMessage({
    required this.text,
    required this.role,
    this.imageUrls = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasImages => imageUrls.isNotEmpty;
}
