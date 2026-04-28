import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env_config.dart';
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
  static const _apiBaseUrl = 'https://lanfengai.cn';
  static const _imageGenerationUrl = '$_apiBaseUrl/v1/images/generations';
  static const _imageEditUrl = '$_apiBaseUrl/v1/images/edits';
  static const _model = 'gpt-image-2';

  Future<ChatResponse> sendMessage({
    required String prompt,
    required ImageGenerationOptions options,
    ChatImageAttachment? imageAttachment,
  }) async {
    if (openAIApiKey.isEmpty || openAIApiKey == '<YOUR_OPENAI_API_KEY>') {
      throw Exception('请在环境变量或 .env 文件中填写可用的 API Key。');
    }

    final normalizedOptions = options.normalized();
    if (imageAttachment == null) {
      return _sendGenerationRequest(
        prompt: prompt,
        options: normalizedOptions,
      );
    }

    return _sendEditRequest(
      prompt: prompt,
      options: normalizedOptions,
      imageAttachment: imageAttachment,
    );
  }

  Future<ChatResponse> _sendGenerationRequest({
    required String prompt,
    required ImageGenerationOptions options,
  }) async {
    final response = await http.post(
      Uri.parse(_imageGenerationUrl),
      headers: _jsonHeaders,
      body: jsonEncode({
        'model': _model,
        'prompt': _composePrompt(prompt, options),
        'size': options.aspectRatio,
        'resolution': options.resolution,
        'output_format': options.outputFormat,
        'quality': 'auto',
        'moderation': 'auto',
        'background': 'auto',
        'n': 1,
      }),
    );

    return _parseImageResponse(
      response,
      options: options,
      isEditRequest: false,
    );
  }

  Future<ChatResponse> _sendEditRequest({
    required String prompt,
    required ImageGenerationOptions options,
    required ChatImageAttachment imageAttachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_imageEditUrl),
    );

    request.headers.addAll(_authHeaders);
    request.fields.addAll({
      'model': _model,
      'prompt': _composePrompt(
        prompt.isEmpty ? '请基于输入图片生成新的画面。' : prompt,
        options,
      ),
      'size': options.aspectRatio,
      'resolution': options.resolution,
      'output_format': options.outputFormat,
      'quality': 'auto',
      'moderation': 'auto',
      'background': 'auto',
      'n': '1',
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageAttachment.bytes,
        filename: imageAttachment.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _parseImageResponse(
      response,
      options: options,
      isEditRequest: true,
    );
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $openAIApiKey',
      };

  Map<String, String> get _jsonHeaders => {
        ..._authHeaders,
        'Content-Type': 'application/json',
      };

  String _composePrompt(String prompt, ImageGenerationOptions options) {
    final trimmedPrompt = prompt.trim();
    final suffix =
        '生成要求：尺寸比例 ${options.aspectRatio}，分辨率 ${options.resolution.toUpperCase()}，输出格式 ${options.outputFormat.toUpperCase()}。';

    if (trimmedPrompt.isEmpty) {
      return suffix;
    }

    return '$trimmedPrompt\n\n$suffix';
  }

  ChatResponse _parseImageResponse(
    http.Response response, {
    required ImageGenerationOptions options,
    required bool isEditRequest,
  }) {
    final body = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, body));
    }

    final data = body['data'];
    if (data is! List || data.isEmpty) {
      throw Exception('接口已返回成功，但没有拿到图片结果。');
    }

    final generatedImages = <GeneratedImageAsset>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      if (item is! Map) {
        continue;
      }

      final fileName = _resolveFileName(item, options, index);
      if (item['b64_json'] is String &&
          (item['b64_json'] as String).isNotEmpty) {
        generatedImages.add(
          GeneratedImageAsset(
            bytes: base64Decode(item['b64_json'].toString()),
            fileName: fileName,
            mimeType: mimeTypeForOutputFormat(options.outputFormat),
          ),
        );
        continue;
      }

      if (item['url'] is String && (item['url'] as String).isNotEmpty) {
        generatedImages.add(
          GeneratedImageAsset(
            imageUrl: item['url'].toString(),
            fileName: fileName,
            mimeType: mimeTypeForOutputFormat(options.outputFormat),
          ),
        );
      }
    }

    if (generatedImages.isEmpty) {
      throw Exception('接口响应中未找到可展示的图片数据。');
    }

    final revisedPrompt = _extractRevisedPrompt(data);
    final action = isEditRequest ? '已完成参考图生成' : '已完成图片生成';
    final baseText = '$action，共 ${generatedImages.length} 张。';
    final text =
        revisedPrompt.isEmpty ? baseText : '$baseText\n优化提示词：$revisedPrompt';

    return ChatResponse(
      text: text,
      generatedImages: generatedImages,
    );
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  String _extractErrorMessage(
    http.Response response,
    Map<String, dynamic> body,
  ) {
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

  String _extractRevisedPrompt(List<dynamic> data) {
    for (final item in data) {
      if (item is Map && item['revised_prompt'] != null) {
        final revisedPrompt = item['revised_prompt'].toString().trim();
        if (revisedPrompt.isNotEmpty) {
          return revisedPrompt;
        }
      }
    }

    return '';
  }

  String _resolveFileName(
    Map item,
    ImageGenerationOptions options,
    int index,
  ) {
    final url = item['url']?.toString();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last.trim();
        if (lastSegment.isNotEmpty) {
          return lastSegment;
        }
      }
    }

    final extension = extensionForOutputFormat(options.outputFormat);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'lanfeng_${options.resolution}_${options.aspectRatio.replaceAll(':', 'x')}_${index + 1}_$timestamp.$extension';
  }
}
