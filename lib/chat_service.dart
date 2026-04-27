import 'dart:convert';

import 'package:http/http.dart' as http;
import 'env_config.dart';
import 'models.dart';

// 从环境变量获取 API Key（安全方式）
String get openAIApiKey => EnvConfig.getRequired('OPENAI_API_KEY');

class ChatResponse {
  final String text;
  final List<String> imageUrls;

  ChatResponse({required this.text, this.imageUrls = const []});
}

class OpenAIChatService {
  static const _apiUrl = 'https://www.packyapi.com/v1/chat/completions';

  Future<ChatResponse> sendMessage({
    required String prompt,
    ChatImageAttachment? imageAttachment,
  }) async {
    if (openAIApiKey.isEmpty || openAIApiKey == '<YOUR_OPENAI_API_KEY>') {
      throw Exception('请在 lib/chat_service.dart 中填写你的 OpenAI API Key。');
    }

    final url = Uri.parse(_apiUrl);
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAIApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-image-2',
        'messages': [
          {
            'role': 'user',
            'content': _buildMessageContent(
              prompt: prompt,
              imageAttachment: imageAttachment,
            ),
          },
        ],
        'temperature': 0.8,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI API 请求失败：${response.statusCode} ${response.reasonPhrase}');
    }

    final body = jsonDecode(response.body);
    final content = body['choices']?[0]?['message']?['content'];
    if (content == null) {
      throw Exception('无法解析 OpenAI 响应。');
    }

    return _parseResponseContent(content);
  }

  static final _imageMarkdownRegex =
      RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)');

  Object _buildMessageContent({
    required String prompt,
    ChatImageAttachment? imageAttachment,
  }) {
    if (imageAttachment == null) {
      return prompt;
    }

    return [
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {
          'url': _buildDataUrl(imageAttachment),
        },
      },
    ];
  }

  String _buildDataUrl(ChatImageAttachment attachment) {
    final encoded = base64Encode(attachment.bytes);
    return 'data:${attachment.mimeType};base64,$encoded';
  }

  ChatResponse _parseResponseContent(dynamic content) {
    if (content is String) {
      final imageUrls = _extractImageUrls(content);
      final cleanText = content.replaceAll(_imageMarkdownRegex, '').trim();
      return ChatResponse(text: cleanText, imageUrls: imageUrls);
    }

    if (content is List) {
      final textParts = <String>[];
      final imageUrls = <String>[];

      for (final item in content) {
        if (item is! Map) continue;

        final type = item['type']?.toString();
        if (type == 'text' && item['text'] != null) {
          textParts.add(item['text'].toString().trim());
        }

        if (type == 'image_url') {
          final imagePart = item['image_url'];
          if (imagePart is Map && imagePart['url'] != null) {
            imageUrls.add(imagePart['url'].toString());
          } else if (imagePart is String && imagePart.isNotEmpty) {
            imageUrls.add(imagePart);
          }
        }
      }

      return ChatResponse(
        text: textParts.where((part) => part.isNotEmpty).join('\n\n').trim(),
        imageUrls: imageUrls,
      );
    }

    return ChatResponse(text: content.toString().trim());
  }

  List<String> _extractImageUrls(String text) {
    final imageUrls = <String>[];
    for (final match in _imageMarkdownRegex.allMatches(text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }
    return imageUrls;
  }
}
