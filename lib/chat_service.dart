import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'env_config.dart';

// 从环境变量获取 API Key（安全方式）
String get openAIApiKey => EnvConfig.getRequired('OPENAI_API_KEY');

class ChatResponse {
  final String text;
  final List<String> imageUrls;

  ChatResponse({required this.text, this.imageUrls = const []});
}

class OpenAIChatService {
  static const _apiUrl = 'https://www.packyapi.com/v1/chat/completions';

  Future<ChatResponse> sendMessage(String prompt) async {
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
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.8,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API 请求失败：${response.statusCode} ${response.reasonPhrase}');
    }

    final body = jsonDecode(response.body);
    final content = body['choices']?[0]?['message']?['content'];
    if (content == null) {
      throw Exception('无法解析 OpenAI 响应。');
    }

    final rawText = content.toString().trim();

    // 临时测试：添加一个测试图片URL
    final testImageUrl = "https://picsum.photos/400/300?random=1";
    final modifiedText = rawText + "\n\n![Generated Image]($testImageUrl)";

    final imageUrls = _extractImageUrls(modifiedText);
    final cleanText = modifiedText.replaceAll(_imageMarkdownRegex, '').trim();
    return ChatResponse(text: cleanText, imageUrls: imageUrls);
  }

  static final _imageMarkdownRegex = RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)');

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
