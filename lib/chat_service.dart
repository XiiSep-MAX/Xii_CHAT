import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env_config.dart';
import 'license_service.dart';
import 'models.dart';

// 从环境变量获取 API Key（安全方式）
String get openAIApiKey => EnvConfig.getRequired('OPENAI_API_KEY');

class ChatResponse {
  final String text;
  final List<GeneratedImageAsset> generatedImages;

  ChatResponse({
    required this.text,
    this.generatedImages = const [],
  });
}

class OpenAIChatService {
  static final _imageMarkdownRegex =
      RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)');
  static final _directImageUrlRegex = RegExp(
    r'https?://[^\s]+?\.(?:png|jpe?g|webp|gif)(?:\?[^\s)]*)?',
    caseSensitive: false,
  );

  static String get _apiUrl {
    final configuredBaseUrl = EnvConfig.get('OPENAI_BASE_URL')?.trim();
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      final trimmed = configuredBaseUrl.replaceAll(RegExp(r'/+$'), '');
      if (trimmed.endsWith('/chat/completions')) {
        return trimmed;
      }
      if (trimmed.endsWith('/v1')) {
        return '$trimmed/chat/completions';
      }
      return '$trimmed/v1/chat/completions';
    }

    return 'https://www.packyapi.com/v1/chat/completions';
  }

  static String get _model {
    final configuredModel = EnvConfig.get('OPENAI_IMAGE_MODEL')?.trim();
    if (configuredModel != null && configuredModel.isNotEmpty) {
      return configuredModel;
    }
    return 'gpt-image-2';
  }

  static String? get _workerBaseUrl {
    final configured = EnvConfig.get('LICENSE_API_BASE_URL')?.trim();
    if (configured == null || configured.isEmpty) {
      return null;
    }
    return configured.replaceAll(RegExp(r'/+$'), '');
  }

  Future<ChatResponse> sendMessage({
    required String prompt,
    required ImageGenerationOptions options,
    ChatImageAttachment? imageAttachment,
  }) async {
    final normalizedOptions = options.normalized();
    final composedPrompt = _composePrompt(
      prompt: prompt,
      options: normalizedOptions,
      hasReferenceImage: imageAttachment != null,
    );

    final workerBaseUrl = _workerBaseUrl;
    if (workerBaseUrl != null && workerBaseUrl.isNotEmpty) {
      return _sendViaWorker(
        workerBaseUrl: workerBaseUrl,
        prompt: prompt,
        composedPrompt: composedPrompt,
        options: normalizedOptions,
        imageAttachment: imageAttachment,
      );
    }

    if (openAIApiKey.isEmpty || openAIApiKey == '<YOUR_OPENAI_API_KEY>') {
      throw Exception('请在环境变量或 .env 文件中填写可用的 API Key。');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAIApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': _buildMessageContent(
              prompt: composedPrompt,
              imageAttachment: imageAttachment,
            ),
          },
        ],
        'temperature': 0.8,
      }),
    );

    final body = _decodeJsonFromResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, body));
    }

    final content = _extractResponseContent(body);
    if (content == null) {
      throw Exception('无法解析 PackyAPI 响应。');
    }

    return _parseResponseContent(
      content,
      options: normalizedOptions,
      isEditRequest: imageAttachment != null,
    );
  }

  Future<ChatResponse> _sendViaWorker({
    required String workerBaseUrl,
    required String prompt,
    required String composedPrompt,
    required ImageGenerationOptions options,
    required ChatImageAttachment? imageAttachment,
  }) async {
    final licenseStatus = await LicenseService.instance.initialize();
    final response = await http.post(
      Uri.parse('$workerBaseUrl/v1/chat/generate'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': licenseStatus.licenseToken,
        'installId': licenseStatus.installId,
        'prompt': prompt,
        'composedPrompt': composedPrompt,
        'aspectRatio': options.aspectRatio,
        'referenceImage': imageAttachment == null
            ? null
            : {
                'name': imageAttachment.name,
                'mimeType': imageAttachment.mimeType,
                'bytesBase64': base64Encode(imageAttachment.bytes),
              },
      }),
    );

    final body = _decodeJsonFromResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, body));
    }

    final content = body['content'] ?? body['data'] ?? body;
    return _parseResponseContent(
      content,
      options: options,
      isEditRequest: imageAttachment != null,
    );
  }

  String _composePrompt({
    required String prompt,
    required ImageGenerationOptions options,
    required bool hasReferenceImage,
  }) {
    final trimmedPrompt = prompt.trim();
    final basePrompt = trimmedPrompt.isEmpty
        ? (hasReferenceImage ? '请基于输入图片生成新的画面。' : '请生成一张图片。')
        : trimmedPrompt;

    return '$basePrompt\n\n'
        '生成要求：尺寸比例 ${options.aspectRatio}。';
  }

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

  Map<String, dynamic> _decodeJsonFromResponse(http.Response response) {
    final rawBody =
        utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (rawBody.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  dynamic _extractResponseContent(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map && message['content'] != null) {
          return message['content'];
        }
      }
    }

    if (body['data'] != null) {
      return body['data'];
    }

    return null;
  }

  ChatResponse _parseResponseContent(
    dynamic content, {
    required ImageGenerationOptions options,
    required bool isEditRequest,
  }) {
    final generatedImages = <GeneratedImageAsset>[];
    final textParts = <String>[];
    final seenUrls = <String>{};

    void addImageUrl(String url) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty || !seenUrls.add(normalizedUrl)) {
        return;
      }

      generatedImages.add(
        GeneratedImageAsset(
          imageUrl: normalizedUrl,
          fileName: _resolveFileNameFromUrl(normalizedUrl, options),
          mimeType: _resolveMimeTypeFromUrl(normalizedUrl),
        ),
      );
    }

    void addText(String value) {
      final stripped = _stripImageMarkdown(value).trim();
      if (stripped.isNotEmpty) {
        textParts.add(stripped);
      }
      for (final url in _extractImageUrls(value)) {
        addImageUrl(url);
      }
    }

    if (content is String) {
      addText(content);
    } else if (content is List) {
      for (final item in content) {
        if (item is! Map) {
          continue;
        }

        final type = item['type']?.toString();
        if ((type == 'text' || type == 'output_text') && item['text'] != null) {
          addText(item['text'].toString());
          continue;
        }

        if ((type == 'image_url' || type == 'output_image') &&
            item['image_url'] != null) {
          final imagePart = item['image_url'];
          if (imagePart is Map && imagePart['url'] != null) {
            addImageUrl(imagePart['url'].toString());
          } else if (imagePart is String) {
            addImageUrl(imagePart);
          }
          continue;
        }

        if (item['text'] != null) {
          addText(item['text'].toString());
        }

        final directUrl = _readImageUrlFromMap(item);
        if (directUrl != null) {
          addImageUrl(directUrl);
        }
      }
    } else if (content is Map) {
      if (content['text'] != null) {
        addText(content['text'].toString());
      }

      final directUrl = _readImageUrlFromMap(content);
      if (directUrl != null) {
        addImageUrl(directUrl);
      }
    } else {
      final fallbackText = content.toString().trim();
      if (fallbackText.isNotEmpty) {
        addText(fallbackText);
      }
    }

    final responseText = textParts.join('\n\n').trim();
    if (generatedImages.isNotEmpty) {
      final action = isEditRequest ? '已完成参考图生成' : '已完成图片生成';
      final fallbackText = '$action，共 ${generatedImages.length} 张。';
      return ChatResponse(
        text: responseText.isEmpty ? fallbackText : responseText,
        generatedImages: generatedImages,
      );
    }

    if (responseText.isNotEmpty) {
      return ChatResponse(text: responseText);
    }

    throw Exception('接口已返回成功，但没有解析到图片结果。');
  }

  String _extractErrorMessage(
    http.Response response,
    Map<String, dynamic> body,
  ) {
    if (body['error'] != null) {
      return body['error'].toString();
    }
    final error = body['error'];
    if (error is Map && error['message'] != null) {
      return '图片生成请求失败：${error['message']}';
    }
    if (body['message'] != null) {
      return '图片生成请求失败：${body['message']}';
    }
    return '图片生成请求失败：HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}'
        .trim();
  }

  List<String> _extractImageUrls(String text) {
    final imageUrls = <String>[];

    for (final match in _imageMarkdownRegex.allMatches(text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }

    for (final match in _directImageUrlRegex.allMatches(text)) {
      final url = match.group(0);
      if (url != null && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }

    return imageUrls;
  }

  String _stripImageMarkdown(String text) {
    return text.replaceAll(_imageMarkdownRegex, '').trim();
  }

  String? _readImageUrlFromMap(Map<dynamic, dynamic> item) {
    final candidates = [
      item['url'],
      item['image_url'],
      item['imageUrl'],
      item['output_url'],
      item['outputUrl'],
    ];

    for (final candidate in candidates) {
      final url = candidate?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  String _resolveFileNameFromUrl(
    String url,
    ImageGenerationOptions options,
  ) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last.trim();
      if (lastSegment.isNotEmpty) {
        return lastSegment;
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'packy_${options.aspectRatio.replaceAll(':', 'x')}_$timestamp.png';
  }

  String _resolveMimeTypeFromUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerUrl.contains('.webp')) {
      return 'image/webp';
    }
    if (lowerUrl.contains('.gif')) {
      return 'image/gif';
    }
    return 'image/png';
  }
}
