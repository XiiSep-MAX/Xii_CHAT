import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  static String get _imageApiBaseUrl {
    final chatUrl = _apiUrl;
    if (chatUrl.endsWith('/chat/completions')) {
      return chatUrl.substring(0, chatUrl.length - '/chat/completions'.length);
    }
    if (chatUrl.endsWith('/v1')) {
      return chatUrl;
    }
    return '$chatUrl/v1';
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
    List<ChatImageAttachment> imageAttachments = const [],
  }) async {
    final normalizedOptions = options.normalized();
    final composedPrompt = _composePrompt(
      prompt: prompt,
      options: normalizedOptions,
      hasReferenceImage: imageAttachments.isNotEmpty,
    );

    final workerBaseUrl = _workerBaseUrl;
    if (workerBaseUrl != null && workerBaseUrl.isNotEmpty) {
      return _sendViaWorker(
        workerBaseUrl: workerBaseUrl,
        prompt: prompt,
        composedPrompt: composedPrompt,
        options: normalizedOptions,
        imageAttachments: imageAttachments,
      );
    }

    if (openAIApiKey.isEmpty || openAIApiKey == '<YOUR_OPENAI_API_KEY>') {
      throw Exception('请在环境变量或 .env 文件中填写可用的 API Key。');
    }

    final response = imageAttachments.isEmpty
        ? await _sendGenerationRequest(
            prompt: composedPrompt,
            options: normalizedOptions,
          )
        : await _sendEditRequest(
            prompt: composedPrompt,
            options: normalizedOptions,
            imageAttachments: imageAttachments,
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
      isEditRequest: imageAttachments.isNotEmpty,
    );
  }

  Future<ChatResponse> editGeneratedImage({
    required String prompt,
    required ImageGenerationOptions options,
    required ChatImageAttachment sourceImage,
    ChatImageAttachment? maskImage,
  }) async {
    final normalizedOptions = options.normalized();
    final composedPrompt = _composePrompt(
      prompt: prompt,
      options: normalizedOptions,
      hasReferenceImage: true,
    );

    final workerBaseUrl = _workerBaseUrl;
    if (workerBaseUrl != null && workerBaseUrl.isNotEmpty) {
      return _sendEditViaWorker(
        workerBaseUrl: workerBaseUrl,
        prompt: prompt,
        composedPrompt: composedPrompt,
        options: normalizedOptions,
        sourceImage: sourceImage,
        maskImage: maskImage,
      );
    }

    if (openAIApiKey.isEmpty || openAIApiKey == '<YOUR_OPENAI_API_KEY>') {
      throw Exception('请在环境变量或 .env 文件中填写可用的 API Key。');
    }

    final response = await _sendEditRequest(
      prompt: composedPrompt,
      options: normalizedOptions,
      imageAttachments: [sourceImage],
      maskAttachment: maskImage,
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
      isEditRequest: true,
    );
  }

  Future<http.Response> _sendGenerationRequest({
    required String prompt,
    required ImageGenerationOptions options,
  }) {
    return http.post(
      Uri.parse('$_imageApiBaseUrl/images/generations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAIApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'prompt': prompt,
        'n': 1,
        'size': options.size,
        'quality': options.quality,
        'output_format': 'png',
        'response_format': 'url',
      }),
    );
  }

  Future<http.Response> _sendEditRequest({
    required String prompt,
    required ImageGenerationOptions options,
    required List<ChatImageAttachment> imageAttachments,
    ChatImageAttachment? maskAttachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_imageApiBaseUrl/images/edits'),
    );

    request.headers['Authorization'] = 'Bearer $openAIApiKey';
    request.fields.addAll({
      'model': _model,
      'prompt': prompt,
      'n': '1',
      'size': options.size,
      'quality': options.quality,
      'output_format': 'png',
      'response_format': 'url',
      'input_fidelity': 'high',
    });

    for (final attachment in imageAttachments) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          attachment.bytes,
          filename: attachment.name,
          contentType: _parseMediaType(attachment.mimeType),
        ),
      );
    }

    if (maskAttachment != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'mask',
          maskAttachment.bytes,
          filename: maskAttachment.name,
          contentType: _parseMediaType(maskAttachment.mimeType),
        ),
      );
    }

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  Future<ChatResponse> _sendViaWorker({
    required String workerBaseUrl,
    required String prompt,
    required String composedPrompt,
    required ImageGenerationOptions options,
    required List<ChatImageAttachment> imageAttachments,
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
        'size': options.size,
        'quality': options.quality,
        'referenceImages': imageAttachments
            .map(
              (image) => {
                'name': image.name,
                'mimeType': image.mimeType,
                'bytesBase64': base64Encode(image.bytes),
              },
            )
            .toList(growable: false),
      }),
    );

    final body = _decodeJsonFromResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, body));
    }
    _throwIfLegacyQueuedWorkerResponse(body);

    final content = body['content'] ?? body['data'] ?? body;
    _throwIfLegacyQueuedWorkerContent(content);
    return _parseResponseContent(
      content,
      options: options,
      isEditRequest: imageAttachments.isNotEmpty,
    );
  }

  Future<ChatResponse> _sendEditViaWorker({
    required String workerBaseUrl,
    required String prompt,
    required String composedPrompt,
    required ImageGenerationOptions options,
    required ChatImageAttachment sourceImage,
    ChatImageAttachment? maskImage,
  }) async {
    final licenseStatus = await LicenseService.instance.initialize();
    final response = await http.post(
      Uri.parse('$workerBaseUrl/v1/chat/edit-image'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': licenseStatus.licenseToken,
        'installId': licenseStatus.installId,
        'prompt': prompt,
        'composedPrompt': composedPrompt,
        'size': options.size,
        'quality': options.quality,
        'sourceImage': {
          'name': sourceImage.name,
          'mimeType': sourceImage.mimeType,
          'bytesBase64': base64Encode(sourceImage.bytes),
        },
        if (maskImage != null)
          'maskImage': {
            'name': maskImage.name,
            'mimeType': maskImage.mimeType,
            'bytesBase64': base64Encode(maskImage.bytes),
          },
      }),
    );

    final body = _decodeJsonFromResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, body));
    }
    _throwIfLegacyQueuedWorkerResponse(body);

    final content = body['content'] ?? body['data'] ?? body;
    _throwIfLegacyQueuedWorkerContent(content);
    return _parseResponseContent(
      content,
      options: options,
      isEditRequest: true,
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
        '生成要求：尺寸 ${options.size}；质量 ${options.quality}。';
  }

  MediaType? _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length != 2) {
      return null;
    }
    return MediaType(parts.first, parts.last);
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
    if (body['data'] != null) {
      return body['data'];
    }

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

    return null;
  }

  void _throwIfLegacyQueuedWorkerResponse(Map<String, dynamic> body) {
    final status = (body['taskStatus'] ?? body['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final hasLegacyTaskMarkers =
        body['taskId'] != null ||
        body['clientRequestId'] != null ||
        body['taskStatus'] != null;
    if (hasLegacyTaskMarkers && status.isNotEmpty && status != 'completed') {
      throw Exception(
        '当前线上 Worker 仍是旧版任务队列逻辑，尚未返回最终图片结果。请先重新部署已回退到 v1.2.12 的 Worker。',
      );
    }
  }

  void _throwIfLegacyQueuedWorkerContent(dynamic content) {
    if (content is! Map) {
      return;
    }

    final status = (content['taskStatus'] ?? content['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final hasLegacyTaskMarkers =
        content['taskId'] != null ||
        content['clientRequestId'] != null ||
        content['taskStatus'] != null;
    if (hasLegacyTaskMarkers && status.isNotEmpty && status != 'completed') {
      throw Exception(
        '当前线上 Worker 仍是旧版任务队列逻辑，尚未返回最终图片结果。请先重新部署已回退到 v1.2.12 的 Worker。',
      );
    }
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

    void addImageBase64(String value, {String mimeType = 'image/png'}) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }

      generatedImages.add(
        GeneratedImageAsset(
          bytes: base64Decode(normalized),
          fileName: _resolveFileNameFromBytes(options, mimeType),
          mimeType: mimeType,
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

        final b64Json = item['b64_json']?.toString();
        if (b64Json != null && b64Json.isNotEmpty) {
          addImageBase64(b64Json);
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

      final b64Json = content['b64_json']?.toString();
      if (b64Json != null && b64Json.isNotEmpty) {
        addImageBase64(b64Json);
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
    return 'packy_${options.size}_$timestamp.png';
  }

  String _resolveFileNameFromBytes(
    ImageGenerationOptions options,
    String mimeType,
  ) {
    final extension = switch (mimeType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp',
      _ => 'png',
    };

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'packy_${options.size}_$timestamp.$extension';
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
